//
//  NSData+DictCompression.m
//
//  Created by PM on 17.05.14.
//  Copyright (c) 2014 Pavel Mayer. All rights reserved.
//

#import "NSData+DictCompression.h"
#import "NSString+StringWithData.h"
#import "NSData+HexString.h"
#import "NSData+Base64.h"
#import <Foundation/NSUUID.h>

#import "map"
#import "memory"

#define COMPRESSION_TIMING YES
#define SOME_COMPRESSION_TRACE NO
#define COMPRESSION_TRACE NO
#define MORE_COMPRESSION_TRACE NO
#define TREE_COMP_TRACE NO
#define TREE_FIND_TRACE NO


typedef NSRange (^CompressBlock)(NSMutableData * data, NSRange range);


@implementation NSData (DictCompression)


enum {
    DICT_LIMIT = 240,
    HEX_LOWERCASE             = 241, //0xf1
    HEX_UPPERCASE             = 242, //0xf2
    HEX_LOWERCASE_QUOTED      = 243, //0xf3
    HEX_UPPERCASE_QUOTED      = 244, //0xf4
    UUID_LOWERCASE            = 245, //0xf5
    UUID_UPPERCASE            = 246, //0xf6
    UUID_LOWERCASE_QUOTED     = 247, //0xf7
    UUID_UPPERRCASE_QUOTED    = 248, //0xf8
    BASE64_SHORT              = 249, //0xf9
    BASE64_LONGER             = 250, //0xfa
    BASE64_SHORT_SLASHESC     = 251, //0xfb
    BASE64_LONGER_SLASHESC    = 252  //0xfc
};

NSString* asciiChar(unsigned char c) {
    NSMutableString * rep = [NSMutableString new];
    if (c >=0x20 && c < 0x7f) {
        [rep appendString:[NSString stringWithFormat:@"%c",c]];
    } else {
        [rep appendString:[NSString stringWithFormat:@"<%d>",c]];
    }
    return rep;
}

- (NSString*)asciiString {
    NSMutableString * rep = [NSMutableString new];
    for (int i = 0; i < self.length; ++i) {
        unsigned char c = ((unsigned char*)self.bytes)[i];
        [rep appendString:asciiChar(c)];
    }
    return rep;
}

- (NSString*)asciiStringWithMaxBytes:(NSUInteger)maxBytes {
    NSMutableString * rep = [NSMutableString new];
    for (int i = 0; i < self.length && i < maxBytes; ++i) {
        unsigned char c = ((unsigned char*)self.bytes)[i];
        [rep appendString:asciiChar(c)];
    }
    if (self.length > maxBytes) {
        rep = [NSMutableString stringWithFormat:@"%@ ...[%@ more bytes]", rep, @(self.length - maxBytes)];
    }
    return rep;
}

template <typename Key, typename Value>
struct Tree {
//    std::map< Key, std::shared_ptr<Tree> > child;
//    std::map< Key, Tree*> child;
    typedef std::map<Key,Tree> type;
    std::map< Key, Tree> child;
    Value value;
};

/*
template<typename T> struct STree {
//    typedef std::map<T,std::shared_ptr<STree> > type;
    typedef std::map<T,STree> type;
};
*/
//typedef STree<unsigned char>::type CharTree;
typedef Tree<unsigned char,int> CharTree;
typedef std::shared_ptr<CharTree> CharTreePtr;



void checkTree(NSArray* dataList, const CharTree & tree) {
    NSLog(@"------->   starting checktree");
    for (int i = 0; i < dataList.count;++i) {
        NSLog(@"--> start of chain %i",i);
        NSData * data = dataList[i];
        int value;
        NSRange found = [data findTree:tree inRange:NSMakeRange(0,data.length) returnValue:value];
        if (found.location != 0) {
            NSLog(@"#### bad location (%@) for %@", @(found.location), [data asciiString]);
        }
        if (found.length != data.length) {
            NSLog(@"### bad length (%@) for %@", @(found.length), [data asciiString]);
        }
        if (value != i+1) {
            NSLog(@"#### bad value (%d) for %@, should be %d", value, [data asciiString], i);
        }
        NSMutableData * mdata =  [[NSMutableData alloc] initWithData:[@"<" dataUsingEncoding:NSUTF8StringEncoding ]];
        [mdata appendData:data];
        [mdata appendData:[@">" dataUsingEncoding:NSUTF8StringEncoding ]];
        NSLog(@"---> check %@",[mdata asciiString]);
        found = [mdata findTree:tree inRange:NSMakeRange(0,mdata.length) returnValue:value];
        if (found.location != 1) {
            NSLog(@"####-2 bad location (%@) for %@", @(found.location), [data asciiString]);
        }
        if (found.length != data.length) {
            NSLog(@"####-2 bad length (%@) for %@", @(found.length), [data asciiString]);
        }
        if (value != i+1) {
            NSLog(@"####-2 bad value (%d) for %@, should be %d", value, [data asciiString], i);
        }
        
    }
    NSLog(@"------->   finished checktree");
}

CharTreePtr makeTreeForDict(NSArray* dataList)  {
    
    CharTreePtr tree = CharTreePtr(new CharTree());
    tree->value = 0;
    
    for (int i = 0; i < dataList.count;++i) {
        //NSLog(@"--> start of chain %i",i);
        NSData * data = dataList[i];
        const unsigned char * bytes = (const unsigned char *)[data bytes];
        CharTree * subtree = &(*tree);
        for (int c = 0; c < data.length;++c) {
            CharTree::type::iterator ti = subtree->child.find(bytes[c]);
            if (ti == subtree->child.end()) {
                //NSLog(@"insert char %c",bytes[c]);
                subtree->child[bytes[c]] = CharTree();
                subtree = &subtree->child[bytes[c]]; // advance to new created tree
                subtree->value = 0; // 0 indicates that it is not the end of the tree
            } else {
                //NSLog(@"found char %c",bytes[c]);
                subtree = &(*ti).second; // advance to next tree
            }
        }
        subtree->value = i+1; // remember index in last tree
        //NSLog(@"--> end of chain %i, index %d",i, subtree->value);
    }
    if (TREE_COMP_TRACE) printTree(*tree ,@"");
    //checkTree(dataList, *tree);
    return tree;
}

NSString * makeRepeatedString(NSString * c, int repeatCount) {
    NSMutableString * result = [NSMutableString new];
    for (int i = 0; i < repeatCount;++i) {
        [result appendString:c];
    }
    return result;
}

void printTree(const CharTree & tree, NSString* prefix) {
    NSUInteger depth = prefix.length;
    if (!tree.child.empty()) {
        for (CharTree::type::const_iterator it = tree.child.begin(); it != tree.child.end();++it) {
            //NSLog(@"Enter depth:%2d c=:%c",depth, it->first);
            const unsigned char c = it->first;
            NSString * line = [NSString stringWithFormat:@"%@%c",prefix,c];
            if (it->second.child.size() > 1) {
                NSLog(@"depth:%2d line: %@ --- %lu",(unsigned)depth, line, it->second.child.size());
            }
            if (it->second.value != 0) {
                NSLog(@"depth:%2d lineX:%@ (%d)\n", (unsigned)prefix.length, line, it->second.value);
            }
            printTree(it->second, line);
        }
    } else {
        //NSLog(@"depth:%2d line: %@ (%d)\n",prefix.length, prefix, tree.value);
    }
}


// return first and longest matching path range
-(NSRange)findTree:(const CharTree &)tree inRange:(NSRange)range returnValue:(int&)returnValue {
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    NSUInteger rangeEnd = range.location+range.length;
    for (NSUInteger i = range.location; i < rangeEnd;++i) {
        const CharTree * subtree = &tree;
        int offs = 0;
        int match = 0;
        int matchLen = 0;
        CharTree::type::const_iterator ti = subtree->child.find(bytes[i]);
        while (ti != subtree->child.end() && i+offs < rangeEnd) {
            if (TREE_FIND_TRACE) NSLog(@"found char %@ pos=%@ offs=%d", asciiChar(bytes[i+offs]),@(i),offs);
            ++offs; // advance index in byte array searched
            subtree = &(*ti).second; // advance tree ptr
            if (subtree->value != 0) {
                match = subtree->value;
                matchLen = offs;
                if (TREE_FIND_TRACE) NSLog(@"fmatch pos=%@ offs=%d value=%d", @(i),offs,match);
            }
            ti = subtree->child.find(bytes[i+offs]); // try next char
        }
        if (TREE_FIND_TRACE) NSLog(@"endwhile pos=%@ offs=%d value=%d DATA=%d TREE=%d", @(i),offs,match,i+offs < rangeEnd,ti != subtree->child.end());
        // we have now either reached the end of the tree or the end of the search range
        if (match != 0) {
            // we have found a full path
            returnValue = match;
            return NSMakeRange(i, matchLen);
        }
        if (TREE_FIND_TRACE) NSLog(@"loop pos=%@ done", @(i));
    }
    returnValue = 0;
    return NSMakeRange(NSNotFound, 0);
}

-(NSData*)dataByReplacingOccurrencesOfData:(NSData*)what withData:(NSData*)replacement {
    NSMutableData * result = [NSMutableData dataWithData:self];
    NSRange where = NSMakeRange(0,result.length);
    do {
        where = [result rangeOfData:what options:0 range:where];
        if (where.location != NSNotFound) {
            [result replaceBytesInRange:where withBytes:replacement.bytes length:replacement.length];
            where.location = where.location + replacement.length;
            where.length = result.length - where.location;
        }
    } while (where.location != NSNotFound && where.length > 0);
    return result;
}

static int findByteIndex(unsigned char byte, const unsigned char * bytes, int size) {
    for (int b = 0; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return -1;
}

static NSInteger findByteIndexFrom(unsigned char byte, const unsigned char * bytes, NSUInteger size, NSUInteger start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom: byte=%d, size=%@, start=%@",byte, @(size), @(start));
    for (NSUInteger b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return NSNotFound;
}

static NSInteger findByteIndexFrom2(unsigned char byte, const unsigned char * bytes, NSUInteger size, NSUInteger start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom2: byte=%d, size=%@, start=%@", byte, @(size), @(start));
    for (NSUInteger b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return size;
}

BOOL isAlphaChar(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= 'A') && (c <='Z'));
}

- (BOOL)isAlphaRange:(NSRange)range {
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isAlphaChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"alpha: bailout on %c (%d) at pos %@", c, c, @(range.location+i));
            return NO;
        }
    }
    return YES;
}

BOOL isLowerHexChar(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= '0') && (c <='9'));
}

- (BOOL)isLowerHexRange:(NSRange)range {
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isLowerHexChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerHexRange: bailout on %c (%d) at pos %@", c, c, @(range.location+i));
            return NO;
        }
    }
    return YES;
}


BOOL isUpperHexChar(unsigned char c) {
    return ((c >= 'A') && (c <='Z')) || ((c >= '0') && (c <='9'));
}

- (BOOL)isUpperHexRange:(NSRange)range {
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isUpperHexChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isUpperHexRange: bailout on %c (%d) at pos %@", c, c, @(range.location+i));
            return NO;
        }
    }
    return YES;
}

// 7c198eef-ab74-42db-9ac1-67ce7dfda355
// 012345678901234567890123456789012345
// 000000000011111111112222222222233333

- (BOOL)canBeUUIDRange:(NSRange)range {
    if (range.length != 36) {
        return NO;
    }
    const unsigned char * bytes = (const unsigned char *)[self bytes] + range.location;
    BOOL hasMinuses = (bytes[8] == '-') && (bytes[13] == '-') && (bytes[18] == '-') && (bytes[23] == '-');
    return hasMinuses;
}


- (BOOL)isUpperUUIDRange:(NSRange)range {
    if ([self canBeUUIDRange:range]) {
        const unsigned char * bytes = (const unsigned char *)[self bytes];
        for (int i = 0; i < range.length;++i) {
            unsigned char c = bytes[range.location+i];
            if (!isUpperHexChar(c) && (c != '-')) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isUpperUUIDRange: bailout on %c (%d) at pos %@ i=%d", c, c,@(range.location+i),i);
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

- (BOOL)isLowerUUIDRange:(NSRange)range {
    if ([self canBeUUIDRange:range]) {
        const unsigned char * bytes = (const unsigned char *)[self bytes];
        for (int i = 0; i < range.length;++i) {
            unsigned char c = bytes[range.location+i];
            if (!isLowerHexChar(c) && c!= '-') {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerUUIDRange: bailout on %c (%d) at pos %@ i=%d", c, c, @(range.location+i),i);
                return NO;
            }
        }
        if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerUUIDRange: is UUID");
        return YES;
    }
    return NO;
}


BOOL isBase64Char(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= 'A') && (c <='Z')) || ((c >= '0') && (c <='9')) || c == '/' || c=='+' || c=='=' || c=='\\';
}

- (BOOL)isBase64Range:(NSRange)range {
    int payload = 0;
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    int pads = 0;
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isBase64Char(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on %c (%d) at pos %@", c, c, @(range.location+i));
            return NO;
        }
        if (c == '=') {
            ++pads;
            if (pads>3) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout pad # %d at pos %@", pads, @(range.location+i));
                return NO;
            }
        } else {
            if (pads>0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on char after pad # %d at pos %@", pads, @(range.location+i));
                return NO;
            }
        }
        if (c != '\\') {
            ++payload;
        }
    }
    if (payload % 4 != 0) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on payload len not multiple of 4  (%d)",payload);
        return NO;
    }
    return YES;
}

- (NSRange) rangeOfQuotedBase64StringInRange:(NSRange)range {
    NSRange searchRange = range;
    const unsigned char * bytes = (const unsigned char *)[self bytes];
    NSInteger nextQuote = -1;
    NSUInteger rangeEnd = range.location + range.length;
    do {
        nextQuote = findByteIndexFrom('"', bytes, rangeEnd, searchRange.location);
        if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom returned nextQuote@%@",@(nextQuote));
        if (nextQuote >= 0) {
            NSInteger closingQuote = findByteIndexFrom('"', bytes, rangeEnd, nextQuote+1);
            if (closingQuote >= 0) {
                NSRange base64Range = NSMakeRange(nextQuote+1, closingQuote - nextQuote - 1);
                if (base64Range.length >=8 && [self isBase64Range:base64Range] &&
                    ![self isAlphaRange:base64Range] &&
                    ![self isUpperHexRange:base64Range] &&
                    ![self isLowerHexRange:base64Range] &&
                    ![self isUpperUUIDRange:base64Range] &&
                    ![self isLowerUUIDRange:base64Range] )
                {
                    return base64Range;
                } else {
                    searchRange = NSMakeRange(closingQuote, rangeEnd - closingQuote);
                }
            } else {
                nextQuote = closingQuote; // end search if no closing quote
            }
        }
    } while (nextQuote >= 0);
    return NSMakeRange(NSNotFound, 0);
}


- (NSRange) rangeOfLowerUUIdStringInRange:(NSRange)range {
    if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: searching in range from %@ size %@",@(range.location), @(range.length));
    NSRange search = NSMakeRange(range.location, 36);
    NSUInteger rangeEnd = range.location + range.length;
    for (;search.location+search.length < rangeEnd; ++search.location) {
        //if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: checking range from %d size %d",search.location, search.length);
        if ([self isLowerUUIDRange:search]) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: found UUID %@",[[self subdataWithRange:search] asciiString]);
            return search;
        }
    }
    if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: no UUID found in range from %@ size %@", @(range.location), @(range.length));
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange) rangeOfUpperUUIdStringInRange:(NSRange)range {
    NSRange search = NSMakeRange(range.location, 36);
    for (;search.location+search.length < range.location; ++search.location) {
        if ([self isUpperUUIDRange:search]) {
            return search;
        }
    }
    return NSMakeRange(NSNotFound, 0);
}


// return the first range of bytes in inRange where all bytes are contained in bytesset
- (NSRange) rangeOfBytesFromSet:(NSData*)byteSet range:(NSRange)range minLenght:(NSUInteger)minLength {
    unsigned char min = 255;
    unsigned char max = 0;
    const unsigned char * bytes = (unsigned char*)byteSet.bytes;
    for (int i = 0; i < byteSet.length;++i) {
        unsigned char byte = bytes[i];
        if (byte < min) min = byte;
        if (byte > max) max = byte;
    }
    unsigned char * rangeBytes = (unsigned char*)self.bytes;

    NSInteger matchStart = NSNotFound;
    int matchLen = 0;
    for (NSUInteger i = range.location; i < range.location + range.length; ++i) {
        int found = -1;
        if (rangeBytes[i] >= min || rangeBytes[i] <= max) {
            found = findByteIndex(rangeBytes[i], bytes, (int)byteSet.length);
        }
        if (found >= 0) {
            // found
            ++matchLen;
            if (matchStart == NSNotFound) {
                matchStart = i;
            }
        } else {
            // not found
            if (matchStart != NSNotFound) {
                if (matchLen >= minLength) {
                    return NSMakeRange(matchStart, matchLen);
                } else {
                    matchLen = 0;
                    matchStart = NSNotFound;
                }
            }
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

static const unsigned char hex_bytes_lower[17] = "0123456789abcdef";
static const unsigned char hex_bytes_upper[17] = "0123456789ABCDEF";

NSData * dataFromBytes(const unsigned char * bytes, int len) {
    return [NSData dataWithBytes:bytes length:len];
}

NSMutableData * mutableDataFromBytes(const unsigned char * bytes, int len) {
    return [NSMutableData dataWithBytes:bytes length:len];
}

NSRange minLocation(NSRange a, NSRange b) {
    if (a.location <= b.location) return a;
    return b;
}
    
unsigned char getOpcode(BOOL isUUID, BOOL isUpperCase, BOOL isQuoted) {
    int index = 0;
    if (isUpperCase) index+=1;
    if (isQuoted) index+=2;
    if (isUUID) index += 4;
    return HEX_LOWERCASE+index;
}

BOOL opcodeIsQuoted(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 2) != 0;
}

BOOL opcodeIsUppercase(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 1) != 0;
}

BOOL opcodeIsUUID(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 4) != 0;
}

BOOL opcodeIsHex(unsigned char opcode) {
    return (opcode >= HEX_LOWERCASE && opcode <=HEX_LOWERCASE+7);
}

BOOL opcodeIsBase64(unsigned char opcode) {
    return (opcode >= BASE64_SHORT && opcode <=BASE64_LONGER_SLASHESC);
}

BOOL opcodeIsConst(unsigned char opcode) {
    return opcodeIsDictionary(opcode) || (opcodeIsHex(opcode) && opcodeIsUUID(opcode));
}

BOOL opcodeIsShort(unsigned char opcode) {
    return opcode == BASE64_SHORT || opcode == BASE64_SHORT_SLASHESC ||(opcodeIsHex(opcode) && !opcodeIsUUID(opcode));
}

BOOL opcodeIsLonger(unsigned char opcode) {
    return opcode == BASE64_LONGER || opcode == BASE64_LONGER_SLASHESC;
}

BOOL opcodeIsSlashEscaped(unsigned char opcode) {
    return opcode == BASE64_SHORT_SLASHESC || opcode == BASE64_LONGER_SLASHESC;
}


int operationEncodedSize(unsigned char opcode, const unsigned char * codeblock) {
    if (opcodeIsConst(opcode)) {
        if (opcodeIsDictionary(opcode)) {
            return 2; // 0x0 + index
        } else if (opcodeIsUUID(opcode)) {
            return 2 + 16; // 0x0 + opcode + uuid;
        }
        NSLog(@"error: internal, bad opcode logic");
    }
    // opcode has variable field
    if (opcodeIsShort(opcode)) {
        return 3 + codeblock[2]; // 0x0 + opcode + lenght + content
    }
    if (opcodeIsLonger(opcode)) {
        return 4 + codeblock[2] * 256 + codeblock[3]; // 0x0 + opcode + lenght + content
    }
    NSLog(@"ERROR: can not determine operationEncodedSize");
    return 0; // no opcode
}

BOOL opcodeIsDictionary(unsigned char opcode) {
    if (opcode < DICT_LIMIT) {
        if (opcode > 0) {
            return YES;
        }
        NSLog(@"illegal null opcode");
    }
    return NO;
}

- (NSData*)iterateOverUncompressedWithMinSize:(NSUInteger)minSize withBlock:(CompressBlock)compress {
    NSMutableData * result = [NSMutableData dataWithData:self];
    NSRange searchRange = NSMakeRange(0,result.length);
    NSInteger start = 0;
    NSInteger stop = findByteIndexFrom2(0, (const unsigned char *)result.bytes, result.length, searchRange.location);
    while (stop >= 0 && start < result.length) {
        NSInteger gap = stop - start;
        if (MORE_COMPRESSION_TRACE) NSLog(@"start: %@ stop %@ gap %@", @(start), @(stop), @(gap));
        if (gap >= minSize) {
            NSRange done = compress(result, NSMakeRange(start, gap));
            start = done.location + done.length;
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"gap %@ smaller than min %@", @(gap), @(minSize));
            start = stop;
        }
        if (start < result.length) {
            const unsigned char * bytes = (const unsigned char *)result.bytes;
            if (MORE_COMPRESSION_TRACE) NSLog(@"check pos %@ for 0", @(start));
            if (bytes[start] == 0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %@ is zero", @(start));
                unsigned char opcode = bytes[start+1];
                int skip = operationEncodedSize(opcode, bytes+start);
                if (MORE_COMPRESSION_TRACE) NSLog(@"skip:%d", skip);
                start += skip;
            } else {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %@ is not zero, searching for next zero as stop", @(start));
            }
            stop = findByteIndexFrom2(0, (const unsigned char *)result.bytes, result.length, start);
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"pos %@ has reached end", @(start));
        }
    };
    return result;
}

- (NSData*)performDictCompressionWithDict:(NSArray*)dict {
    NSMutableArray * dataDict = [NSMutableArray new];
    NSMutableArray * opcodes = [NSMutableArray new];
    NSData * result = self;
    for (int i = 0; i < dict.count;++i) {
        NSData * entry = dict[i];
        if ([entry isKindOfClass:[NSString class]]) {
            // convert string from dict to data
            [dataDict addObject: [(NSString*)entry dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [dataDict addObject: entry];
        }
        entry = dataDict[i];
        if (findByteIndex(0, (const unsigned char *)entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
        unsigned char indexReference[2] = {0, (unsigned char)(i+1)};
        [opcodes addObject:dataFromBytes(indexReference, 2)];
        
        if (MORE_COMPRESSION_TRACE) NSLog(@"\n");
        if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);

        result  = [result iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch range from %@ size %@", @(range.location), @(range.length));
            if (entry.length <= range.length) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);
                NSRange found = [data rangeOfData:entry options:0 range:range];
                if (found.location != NSNotFound) {
                    NSData * refop = opcodes[i];
                    if (COMPRESSION_TRACE) NSLog(@"dictSearch found %@ at %@", [entry asciiString], @(found.location));
                    if (COMPRESSION_TRACE) NSLog(@"Dict: replacing %@ with %@",[[data subdataWithRange:found] asciiString], [refop asciiString] );
                    if (MORE_COMPRESSION_TRACE) NSLog(@"before=%@",[data asciiString]);
                    [data replaceBytesInRange:found withBytes:refop.bytes length:refop.length];
                    if (MORE_COMPRESSION_TRACE) NSLog(@"after=%@",[data asciiString]);
                    if (SOME_COMPRESSION_TRACE) NSLog(@"match (reduced %@->%@):%@ (at %@)", @(found.length) , @(refop.length), [entry asciiString], @(found.location));
                    return NSMakeRange(found.location, refop.length);
                }
            }
            return range;
        }];
    }
    return result;
}


- (NSData*)performDictTreeCompressionWitTree:(const CharTree &)tree {
    
    NSData * result = self;
    
    result  = [result iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        if (MORE_COMPRESSION_TRACE | TREE_COMP_TRACE) NSLog(@"dictTree search range from %@ size %@", @(range.location), @(range.length));
        int value = 0;
        NSRange found = [data findTree:tree inRange:range returnValue:value];
        if (MORE_COMPRESSION_TRACE| TREE_COMP_TRACE) NSLog(@"findtree returned pos=%@ len=%@ index=%d", @(found.location), @(found.length), value);
        if (found.location != NSNotFound) {
            unsigned char refop[2] = {0, (unsigned char)value};
            NSString * replacing = nil;
            if (COMPRESSION_TRACE | SOME_COMPRESSION_TRACE| TREE_COMP_TRACE) {
                replacing = [[data subdataWithRange:found] asciiString];
                if (COMPRESSION_TRACE| TREE_COMP_TRACE) NSLog(@"Tree: replacing %@ with %@",replacing, [dataFromBytes(refop, 2) asciiString] );
            }
            if (MORE_COMPRESSION_TRACE| TREE_COMP_TRACE) NSLog(@"before=%@",[data asciiString]);
            
            [data replaceBytesInRange:found withBytes:(unsigned char*)refop length:2];
            
            if (MORE_COMPRESSION_TRACE| TREE_COMP_TRACE) NSLog(@"after=%@",[data asciiString]);
            if (SOME_COMPRESSION_TRACE| TREE_COMP_TRACE) NSLog(@"tree  (reduced %@->%d):%@ (at %@)",@(found.length),2, replacing, @(found.location));
            return NSMakeRange(found.location, 2);
        }
        return range;
    }];
    return result;
}

-(NSData*) performHexCompression {
    NSData * result2 = self;
    NSData * hexCharsLower = dataFromBytes(hex_bytes_lower, 16);
    NSData * hexCharsUpper = dataFromBytes(hex_bytes_upper, 16);
    
    result2  = [result2 iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"");
        if (MORE_COMPRESSION_TRACE) NSLog(@"hexSearch range from %@ size %@", @(range.location), @(range.length));
        
        //NSRange foundUUIDUpper = [data rangeOfUUIdStringInRange:range upperCase:YES];
        //NSRange foundUUIDLower = [data rangeOfUUIdStringInRange:range upperCase:NO];
        NSRange foundUUIDUpper = [data rangeOfUpperUUIdStringInRange:range];
        NSRange foundUUIDLower = [data rangeOfLowerUUIdStringInRange:range];
        NSRange foundUpper = [data rangeOfBytesFromSet:hexCharsUpper range:range minLenght:6];
        NSRange foundLower = [data rangeOfBytesFromSet:hexCharsLower range:range minLenght:6];
        
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUUIDUpper is range from %@ size %@",@(foundUUIDUpper.location), @(foundUUIDUpper.length));
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUUIDLower is range from %@ size %@",@(foundUUIDLower.location), @(foundUUIDLower.length));
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUpper is range from %@ size %@",@(foundUpper.location), @(foundUpper.length));
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundLower is range from %@ size %@", @(foundLower.location), @(foundLower.length));

        NSRange found = minLocation(foundUUIDLower, minLocation(foundUUIDUpper,minLocation(foundLower,foundUpper)));
        if (MORE_COMPRESSION_TRACE) NSLog(@"using minLocation range from %@ size %@", @(found.location), @(found.length));
        
        if (found.location != NSNotFound) {
            if (found.length > 506) {
                found.length = 506; // limit chunk size to 253 binary bytes
                if (MORE_COMPRESSION_TRACE) NSLog(@"limiting chunk size to 253 binary");
            }
            if (found.length % 2 == 1) {
                found.length = found.length -1; // make even
                if (MORE_COMPRESSION_TRACE) NSLog(@"makeing even -> %@", @(found.length));
            }
            
            if (found.length >=6) {
                BOOL isUUID = NO;
                BOOL isUpperCase = NO;
                
                NSString * debugItem = nil;
                if (found.location == foundUUIDLower.location) {
                    isUUID = YES;
                    debugItem = @"lowercase UUID";
                    
                } else if (found.location == foundUUIDUpper.location) {
                    isUpperCase = YES;
                    isUUID = YES;
                    debugItem = @"uppercase UUID";
                    
                } else if (found.location == foundLower.location) {
                    debugItem = @"lowercase hex";
                    
                } else if (found.location == foundUpper.location) {
                    isUpperCase = YES;
                    debugItem = @"uppercase hex";
                }
                if (MORE_COMPRESSION_TRACE && debugItem != nil) {
                    if (MORE_COMPRESSION_TRACE) NSLog(@"dataWithCompressedHexStrings: Found %@ @ %@, len=%@", debugItem, @(found.location), @(found.length));
                }
                
                NSString * foundString = [NSString stringWithData:[data subdataWithRange:found] usingEncoding:NSUTF8StringEncoding];
                if (COMPRESSION_TRACE) NSLog(@"Found %@ %@ at pos %@",debugItem, foundString, @(found.location));
                BOOL quoted = NO;
                if (found.location > range.location && found.location+found.length+1 < data.length) {
                    // check for quotes
                    const unsigned char * bytes = (const unsigned char *)data.bytes;
                    if (bytes[found.location-1] == '"' && bytes[found.location+found.length] == '"') {
                        quoted = YES;
                        if (COMPRESSION_TRACE) NSLog(@"Found Quoutes");
                    }
                }
                NSData * hexData;
                if (isUUID) {
                    NSString * uuidString = [NSString stringWithData:[data subdataWithRange:found] usingEncoding:NSUTF8StringEncoding];
                    NSUUID * uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
                    if (uuid == nil) {
                        NSLog(@"#ERROR: internal, failed to properly parse uuid");
                        return range;
                    }
                    uuid_t uuidBytes;
                    [uuid getUUIDBytes:uuidBytes];
                    hexData = [NSData dataWithBytes:uuidBytes length:16];
                    
                } else {
                    hexData= [NSData dataWithHexadecimalString:foundString];
                    if (hexData.length != found.length/2) {
                        NSLog(@"#ERROR: internal, failed to properly parse hex string");
                        return range;
                    }
                }
                if (quoted) {
                    found = NSMakeRange(found.location-1, found.length+2);
                }
                //hexData = [hexData escaped];
                if (hexData.length > 253) {
                    NSLog(@"#ERROR: internal, hex string too long for compression");
                    return range;
                }
                unsigned char indexReference[3];
                indexReference[0] = 0;
                indexReference[1] = getOpcode(isUUID, isUpperCase, quoted);
                indexReference[2] = hexData.length;
                
                NSMutableData * hexSequence = [NSMutableData dataWithBytes:indexReference length: isUUID ? 2 : 3];
                [hexSequence appendData:hexData];
                
                NSData * replacedData = nil;
                if (COMPRESSION_TRACE | SOME_COMPRESSION_TRACE) {
                    replacedData = [data subdataWithRange:found];
                    if (COMPRESSION_TRACE) NSLog(@"Replacing:%@", [replacedData asciiString]);
                    if (COMPRESSION_TRACE) NSLog(@"with:%@", [hexSequence asciiString]);
                }
                
                [data replaceBytesInRange:found withBytes:hexSequence.bytes length:hexSequence.length];
                
                if (SOME_COMPRESSION_TRACE) NSLog(@"%@ %@ %@ (reduced %@ -> %@) %@", isUUID?@"uuid":@"hex", isUpperCase?@"uc":@"lc", quoted?@"quoted":@"", @(found.length), @(hexSequence.length), [replacedData asciiStringWithMaxBytes:16]);
                
                NSRange done = NSMakeRange(found.location, hexSequence.length);
                return done;
            } else {
                if (MORE_COMPRESSION_TRACE) NSLog(@"found len too small: %@", @(found.length));
            }
        }
        return range;
    }];
    return result2;
}

-(NSData*) performBase64Compression {
    NSData * result2 = self;
    
    if (COMPRESSION_TRACE) NSLog(@"performBase64Compression input=:%@", [result2 asciiString]);
    
    result2  = [result2 iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        
        NSRange found = [data rangeOfQuotedBase64StringInRange:range];
        
        if (found.location != NSNotFound) {
            NSData * base64StringData = [data subdataWithRange:found];
            NSString * base64String = [NSString stringWithData:base64StringData usingEncoding:NSUTF8StringEncoding];
            
            BOOL slashEscaped = NO;
            if ([base64String rangeOfString:@"\\/"].location != NSNotFound) {
                slashEscaped = YES;
                base64String = [base64String stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            }
            
            NSData * base64Data = [NSData dataWithBase64EncodedString:base64String];
            if (base64Data == nil) {
                NSLog(@"#warning, bad b64 decoding despite checked before, offender = %@",[base64StringData asciiString]);
                return range;
            }
            
            NSMutableData * replacement = nil;
            if (base64Data.length<256) {
                unsigned char short_base64[3] = {0, static_cast<unsigned char>(slashEscaped ? BASE64_SHORT_SLASHESC : BASE64_SHORT), static_cast<unsigned char>(base64Data.length)};
                replacement = mutableDataFromBytes(short_base64,3);
            } else if (base64Data.length < 65536) {
                unsigned char longer_base64[4] = {0, static_cast<unsigned char>(slashEscaped ? BASE64_LONGER_SLASHESC : BASE64_LONGER), static_cast<unsigned char>(base64Data.length/256), static_cast<unsigned char>(base64Data.length % 256)};
                replacement = mutableDataFromBytes(longer_base64,4);
            } else {
                NSLog(@"#warning, b64 block > 64k, not compressing");
            }
            if (MORE_COMPRESSION_TRACE) {
                const unsigned char * bytes = (const unsigned char *)replacement.bytes;
                int oplen = operationEncodedSize(bytes[1], bytes);
                NSLog(@"base64: encoded oplen = %d, base64Data.length=%@, msb=%d, lsb=%d", oplen, @(base64Data.length), bytes[2], bytes[3]);
            }
            NSRange replaceRange = NSMakeRange(found.location-1, found.length+2); // also replace quotes
            if (replacement != nil) {
                [replacement appendData:base64Data];
                
                NSData * replacedData = nil;
                if (COMPRESSION_TRACE | SOME_COMPRESSION_TRACE) {
                    replacedData = [data subdataWithRange:found];
                    if (COMPRESSION_TRACE) NSLog(@"Replacing:%@", [replacedData asciiString]);
                    if (COMPRESSION_TRACE) NSLog(@"with:%@", [replacement asciiString]);
                }
                
                if (COMPRESSION_TRACE) NSLog(@"b64:Replacing:%@", [[data subdataWithRange:found] asciiString]);
                if (COMPRESSION_TRACE) NSLog(@"with:%@", [replacement asciiString]);
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"before replacement:%@", [data asciiString]);
                
                [data replaceBytesInRange:replaceRange withBytes:replacement.bytes length:replacement.length];
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"after  replacement:%@", [data asciiString]);
                
                if (SOME_COMPRESSION_TRACE) NSLog(@"base64 (reduced %@ -> %@) %@", @(replaceRange.length), @(replacement.length), [replacedData asciiStringWithMaxBytes:16]);
                
                NSRange done = NSMakeRange(found.location, replacement.length);
                return done;
            }
        }
        return range;
    }];
    return result2;
 }

- (NSData*)iterateOverCompressedWithBlock:(CompressBlock)decompress {
    
    NSMutableData * result = [NSMutableData dataWithData:self];
    
    NSInteger start = findByteIndexFrom2(0, (const unsigned char *)result.bytes, result.length, 0);
    while (start >= 0 && start != NSNotFound && start+1 < result.length ) {
        const unsigned char * bytes = (const unsigned char *)result.bytes;
        unsigned char opcode = bytes[start+1];
        int compressedSize = operationEncodedSize(opcode, bytes+start);
        NSInteger opEnd = start + compressedSize -1;
        if (opEnd < result.length) {
            NSRange inserted = decompress(result, NSMakeRange(start, compressedSize));
            if (inserted.location == NSNotFound) {
                NSLog(@"iterateOverCompressedWithBlock: decompress failed at pos %@ size %d", @(start), compressedSize);
                return nil;
            }
            start = inserted.location + inserted.length;
        } else {
            NSLog(@"iterateOverCompressedWithBlock: block too short at pos %@, required end = %@, actual size = %@", @(start), @(opEnd), @(result.length));
            return nil;
        }
        start = findByteIndexFrom2(0, (const unsigned char *)result.bytes, result.length, start);
    }
    return result;
}

NSArray * sanitizedDict(NSArray* dict) {
    NSMutableArray * dataDict = [NSMutableArray new];
    for (int i = 0; i < dict.count;++i) {
        NSData * entry = dict[i];
        if ([entry isKindOfClass:[NSString class]]) {
            // convert string from dict to data
            [dataDict addObject: [(NSString*)entry dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [dataDict addObject: entry];
        }
        entry = dataDict[i];
        if (findByteIndex(0, (const unsigned char *)entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
    }
    return dataDict;
}

-(NSData*) performdecompressionWithDict:(NSArray*)dict {
    
    NSArray * dataDict = sanitizedDict(dict);
    
    NSData * result;
    result = [self iterateOverCompressedWithBlock:^NSRange(NSMutableData *data, NSRange range) {
        const unsigned char * bytes = (const unsigned char *)data.bytes;
        unsigned char opcode = bytes[range.location+1];
        NSData * replacement = nil;
        if (opcodeIsDictionary(opcode)) {
            int index = opcode - 1;
            replacement = dataDict[index];
        } else if (opcodeIsHex(opcode)) {
            replacement = hexReplacement([data subdataWithRange:range]);
        } else if (opcodeIsBase64(opcode)) {
            replacement = base64Replacement([data subdataWithRange:range]);
        } else {
            NSLog(@"#ERROR: illegal opcode:%d",opcode);
            return NSMakeRange(NSNotFound, 0);
        }
        if (replacement == nil) {
            NSLog(@"#ERROR: replacement is nil");
            return NSMakeRange(NSNotFound, 0);
        }
        [data replaceBytesInRange:range withBytes:replacement.bytes length:replacement.length];
        NSRange replaced = NSMakeRange(range.location, replacement.length);
        return replaced;
    }];
    return result;
}

NSData * hexReplacement(NSData * compressedData) {
    
    const unsigned char * bytes = (const unsigned char *)compressedData.bytes;
    unsigned char opcode = bytes[1];
    
    BOOL quoted = opcodeIsQuoted(opcode);
    BOOL isUUID = opcodeIsUUID(opcode);
    BOOL isUpperCase = opcodeIsUppercase(opcode);
    
    int srcDataSize = 0;
    if (isUUID) {
        srcDataSize = 16;
    } else {
        srcDataSize = bytes[2];
    }
    if (COMPRESSION_TRACE && quoted) NSLog(@"QUOTED");
    if (COMPRESSION_TRACE && !isUUID) NSLog(@"HEX");
    if (COMPRESSION_TRACE && isUUID) NSLog(@"UUID");
    if (COMPRESSION_TRACE && isUpperCase) NSLog(@"UPPERCASE");
    if (COMPRESSION_TRACE && !isUpperCase) NSLog(@"LOWERCASE");
    
    NSRange srcDataRange = NSMakeRange(isUUID ? 2 : 3, srcDataSize);
    if (srcDataRange.location+srcDataSize != compressedData.length) {
        NSLog(@"#ERROR: hexReplacement: compressedData size matchmatch, expected %@, is %@", @(srcDataRange.location+srcDataSize), @(compressedData.length));
        return nil;
    }
    
    NSData * binaryData = [compressedData subdataWithRange:srcDataRange];

    NSString * hexString;
    if (isUUID) {
        NSUUID * uuid = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)binaryData.bytes];
        hexString = [uuid UUIDString];
    } else {
        hexString = [binaryData hexadecimalString];
    }
    if (isUpperCase) {
        hexString = [hexString uppercaseString];
    } else {
        hexString = [hexString lowercaseString];
    }
    if (quoted) {
        hexString = [NSString stringWithFormat:@"\"%@\"", hexString];
    }
    NSData * hexStringData = [hexString dataUsingEncoding:NSUTF8StringEncoding];
    return hexStringData;
}

NSData * base64Replacement(NSData * compressedData) {
    const unsigned char * bytes = (const unsigned char *)compressedData.bytes;
    unsigned char opcode = bytes[1];
    
    BOOL isLonger = opcodeIsLonger(opcode);
    BOOL isSlashEscaped = opcodeIsSlashEscaped(opcode);
    
    int srcDataSize = 0;
    if (isLonger) {
        srcDataSize = bytes[2] * 256 + bytes[3];
    } else {
        srcDataSize = bytes[2];
    }

    NSRange srcDataRange = NSMakeRange(isLonger ? 4 : 3, srcDataSize);
    if (srcDataRange.location+srcDataSize != compressedData.length) {
        NSLog(@"#ERROR: base64Replacement: compressedData size matchmatch, expected %@, is %@", @(srcDataRange.location+srcDataSize), @(compressedData.length));
        return nil;
    }

    if (COMPRESSION_TRACE && !isLonger) NSLog(@"BASE64 SHORT");
    if (COMPRESSION_TRACE && isLonger) NSLog(@"BASE 64 LONGER");
    if (COMPRESSION_TRACE && isSlashEscaped) NSLog(@"BASE 64 ISSLASHESCAPED");
    
    NSData * binaryData = [compressedData subdataWithRange:srcDataRange];
    NSString * base64String = [binaryData asBase64EncodedString];
    if (isSlashEscaped) {
        base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
    }
    base64String = [NSString stringWithFormat:@"\"%@\"", base64String];
    NSData * base64StringData = [base64String dataUsingEncoding:NSUTF8StringEncoding];
    return base64StringData;
}

static const unsigned char null_byte[1] = {0};
static const unsigned char ff_byte[1] = {0xff};
static const unsigned char ffff_bytes[2] = {0xff,0xff};
static const unsigned char feff_bytes[2] = {0xfe,0xff};

- (NSData*)escaped {
    // escape 0xff as 0xfeff
    NSData * escaped = [self dataByReplacingOccurrencesOfData:dataFromBytes(ff_byte, 1) withData:dataFromBytes(feff_bytes, 2)];
    // turn 0x00 into 0xffff
    escaped = [escaped dataByReplacingOccurrencesOfData:dataFromBytes(null_byte, 1) withData:dataFromBytes(ffff_bytes, 2)];
    return escaped;
}

- (NSData*)unescaped {
    // turn 0xffff into 0x00
    NSData * unescaped = [self dataByReplacingOccurrencesOfData:dataFromBytes(ffff_bytes, 2) withData:dataFromBytes(null_byte, 1) ];
    // unescape 0xff from 0xfeff
    unescaped = [unescaped dataByReplacingOccurrencesOfData:dataFromBytes(feff_bytes, 2) withData:dataFromBytes(ff_byte, 1)];
    return unescaped;
}
/*
 dict, hex, b64:
 2014-05-20 01:00:55.247 Hoccer XO Dev[2150:60b] dictElapsed   3.98 ms
 2014-05-20 01:00:55.248 Hoccer XO Dev[2150:60b] hexElapsed    43.85 ms
 2014-05-20 01:00:55.248 Hoccer XO Dev[2150:60b] b64Elapsed    1.51 ms
 2014-05-20 01:00:55.249 Hoccer XO Dev[2150:60b] total compr.  49.35 ms
 2014-05-20 01:00:55.250 Hoccer XO Dev[2150:60b] decompression 1.00 ms
 2014-05-20 01:00:55.250 Hoccer XO Dev[2150:60b] Original payload        len: 5583
 2014-05-20 01:00:55.251 Hoccer XO Dev[2150:60b] dzlibCompressed payload len: 4020, (72.0%) time 0.87 ms
 2014-05-20 01:00:55.251 Hoccer XO Dev[2150:60b] dictCompressed payload  len: 4084, (73.2%) time 53.49 ms

b64, hex, dict:
 2014-05-20 01:05:44.549 Hoccer XO Dev[2168:60b] dictElapsed   2.88 ms
 2014-05-20 01:05:44.550 Hoccer XO Dev[2168:60b] hexElapsed    6.91 ms
 2014-05-20 01:05:44.550 Hoccer XO Dev[2168:60b] b64Elapsed    1.65 ms
 2014-05-20 01:05:44.551 Hoccer XO Dev[2168:60b] total compr.  11.45 ms
 2014-05-20 01:05:44.552 Hoccer XO Dev[2168:60b] decompression 0.78 ms
 2014-05-20 01:05:44.552 Hoccer XO Dev[2168:60b] Original payload        len: 5583
 2014-05-20 01:05:44.553 Hoccer XO Dev[2168:60b] dzlibCompressed payload len: 4018, (72.0%) time 0.99 ms
 2014-05-20 01:05:44.553 Hoccer XO Dev[2168:60b] dictCompressed payload  len: 4204, (75.3%) time 15.34 ms

 */

- (NSData *) compressWithDict:(NSArray*)rawDict {

    if (rawDict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    NSArray * dict = sanitizedDict(rawDict);
    if (dict == nil) {
        return nil;
    }
    NSDate * treeStartTime = [NSDate new];
    CharTreePtr myTree = makeTreeForDict(dict);
    NSDate * treeStopTime = [NSDate new];
    
    NSData * compressed = [self escaped];
    
    NSDate * startTime = [NSDate new];
    
    // base64
    NSUInteger beforeb64Size = compressed.length;
    NSDate * b64StartTime = [NSDate new];
    compressed = [compressed performBase64Compression];
    NSDate * b64StopTime = [NSDate new];
    NSUInteger afterb64Size = compressed.length;

    // hex
    NSUInteger beforeHexSize = compressed.length;
    NSDate * hexStartTime = [NSDate new];
    compressed = [compressed performHexCompression];
    NSDate * hexStopTime = [NSDate new];
    NSUInteger afterHexSize = compressed.length;

    // dict
    /*
    int beforeDictSize = compressed.length;
    NSDate * dictStartTime = [NSDate new];
    NSData * compressed2 = [compressed performDictCompressionWithDict:dict];
    NSDate * dictStopTime = [NSDate new];
    int afterDictSize = compressed2.length;
     */
    
    // dict tree
    NSUInteger beforeTreeDictSize = compressed.length;
    NSDate * treeDictStartTime = [NSDate new];
    compressed = [compressed performDictTreeCompressionWitTree:*myTree];
    NSDate * treeDictStopTime = [NSDate new];
    NSUInteger afterTreeDictSize = compressed.length;
    
    NSDate * stopTime = [NSDate new];
    
    NSDate * decompStartTime = [NSDate new];
    NSData * check = [compressed decompressWithDict:dict];
    NSDate * decompStopTime = [NSDate new];
 
    if (COMPRESSION_TIMING) {
        NSTimeInterval treeElapsed = [treeStopTime timeIntervalSinceDate:treeStartTime];
        NSTimeInterval treeDictElapsed = [treeDictStopTime timeIntervalSinceDate:treeDictStartTime];
        //NSTimeInterval dictElapsed = [dictStopTime timeIntervalSinceDate:dictStartTime];
        NSTimeInterval hexElapsed = [hexStopTime timeIntervalSinceDate:hexStartTime];
        NSTimeInterval b64Elapsed = [b64StopTime timeIntervalSinceDate:b64StartTime];
        NSTimeInterval decompElapsed = [decompStopTime timeIntervalSinceDate:decompStartTime];
        NSTimeInterval totalComprElapsed = [stopTime timeIntervalSinceDate:startTime];
        
        NSLog(@"treeElapsed   %0.2f ms", treeElapsed*1000);
        NSLog(@"treeDictElapsed   %0.2f ms", treeDictElapsed*1000);
        //NSLog(@"dictElapsed   %0.2f ms", dictElapsed*1000);
        NSLog(@"hexElapsed    %0.2f ms", hexElapsed*1000);
        NSLog(@"b64Elapsed    %0.2f ms", b64Elapsed*1000);
        NSLog(@"total compr.  %0.2f ms", totalComprElapsed*1000);
        NSLog(@"decompression %0.2f ms", decompElapsed*1000);
    }
    
    //if (SOME_COMPRESSION_TRACE) NSLog(@"all dict (reduced %d->%d, %.1f %%)",beforeDictSize, afterDictSize, (double)afterDictSize / (double)beforeDictSize * 100.0);
    if (SOME_COMPRESSION_TRACE) NSLog(@"all tree (reduced %@->%@, %.1f %%)",@(beforeTreeDictSize), @(afterTreeDictSize), (double)afterTreeDictSize / (double)beforeTreeDictSize * 100.0);
    if (SOME_COMPRESSION_TRACE) NSLog(@"all hex  (reduced %@->%@, %.1f %%)", @(beforeHexSize), @(afterHexSize), (double)afterHexSize / (double)beforeHexSize * 100.0);
    if (SOME_COMPRESSION_TRACE) NSLog(@"all b64  (reduced %@->%@, %.1f %%)", @(beforeb64Size), @(afterb64Size), (double)afterb64Size / (double)beforeb64Size * 100.0);

    if (![self isEqualToData:check]) {
        NSLog(@"Compression Error");
        for (int i = 0; i < self.length; ++i) {
            if (((unsigned char*)self.bytes)[i] != ((unsigned char*)check.bytes)[i]) {
                NSLog(@"first diff at pos %d, orig=%d, decoded=%d", i, ((unsigned char*)self.bytes)[i], ((unsigned char*)check.bytes)[i]);
                break;
            }
        }
        NSLog(@"Original=%@", [self asciiString]);
        NSLog(@"Decoded= %@", [check asciiString]);
        NSLog(@"stop");
    }
    return compressed;
}


- (NSData *) decompressWithDict:(NSArray*)dict {
    if (dict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    if (COMPRESSION_TRACE) NSLog(@"DECOMPRESSING");
    if (COMPRESSION_TRACE) NSLog(@"%@", [self asciiString]);
    
    NSData * uncompressed = [self performdecompressionWithDict:dict];
        
    uncompressed = [uncompressed unescaped];
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after unescape:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
    return uncompressed;
}


@end
