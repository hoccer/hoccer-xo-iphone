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

#define COMPRESSION_TRACE YES
#define MORE_COMPRESSION_TRACE NO


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

static int findByteIndexFrom(unsigned char byte, const unsigned char * bytes, int size, int start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom: byte=%d, size=%d, start=%d",byte,size,start);
    for (int b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return -1;
}

static int findByteIndexFrom2(unsigned char byte, const unsigned char * bytes, int size, int start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom2: byte=%d, size=%d, start=%d",byte,size,start);
    for (int b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return size;
}

BOOL isBase64Char(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= 'A') && (c <='Z')) || ((c >= '0') && (c <='9')) || c == '/' || c=='+' || c=='=' || c=='\\';
}

- (BOOL)isBase64Range:(NSRange)range {
    int payload = 0;
    const unsigned char * bytes = [self bytes];
    int pads = 0;
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isBase64Char(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"bailout on %c (%d) at pos %d", c, c,range.location+i);
            return NO;
        }
        if (c == '=') {
            ++pads;
            if (pads>3) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"bailout pad # %d at pos %d", pads,range.location+i);
                return NO;
            }
        } else {
            if (pads>0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"bailout on char after pad # %d at pos %d", pads,range.location+i);
                return NO;
            }
        }
        if (c != '\\') {
            ++payload;
        }
    }
    if (payload % 4 != 0) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"bailout on payload len not multiple of 4  (%d)",payload);
        return NO;
    }
    return YES;
}

- (NSRange) rangeOfQuotedBase64StringInRange:(NSRange)range {
    NSRange searchRange = range;
    const unsigned char * bytes = [self bytes];
    int nextQuote = -1;
    int rangeEnd = range.location + range.length;
    do {
        nextQuote = findByteIndexFrom('"', bytes, rangeEnd, searchRange.location);
        if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom returned nextQuote@%d",nextQuote);
        if (nextQuote >= 0) {
            int closingQuote = findByteIndexFrom('"', bytes, rangeEnd, nextQuote+1);
            if (closingQuote >= 0) {
                NSRange base64Range = NSMakeRange(nextQuote+1, closingQuote - nextQuote - 1);
                if (base64Range.length >=8 && [self isBase64Range:base64Range]) {
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

static const unsigned char UUID_bytes_lower[18] = "0123456789abcdef-";
static const unsigned char UUID_bytes_upper[18] = "0123456789ABCDEF-";


- (NSRange) rangeOfUUIdStringInRange:(NSRange)range upperCase:(BOOL)upperCase{
    NSData * UUIdChars;
    if (upperCase) {
        UUIdChars = dataFromBytes(UUID_bytes_upper, 18);
    } else {
        UUIdChars = dataFromBytes(UUID_bytes_lower, 18);
    }
    NSRange found;
    NSRange searchRange = range;
    const unsigned char * bytes = [self bytes];
    do {
        found = [self rangeOfBytesFromSet:UUIdChars range:searchRange];
        if (found.location != NSNotFound && found.length >= 36) {
            NSRange uuidRange;
            if (found.length >= 38 && bytes[found.location] == '"' && bytes[found.location+37]== '"') {
                // try parse quoted
                uuidRange = NSMakeRange(found.location+1, 36);
            } else {
                uuidRange = NSMakeRange(found.location, 36);
            }
            NSString * uuidString = [NSString stringWithData:[self subdataWithRange:uuidRange] usingEncoding:NSUTF8StringEncoding];
            NSUUID * uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
            if (uuid != nil) {
                return uuidRange;
            }
        }
        searchRange = NSMakeRange(found.location+found.length, self.length - (found.location+found.length));
    } while (found.location != NSNotFound);
    return NSMakeRange(NSNotFound, 0);
}


// return the first range of bytes in inRange where all bytes are contained in bytesset
- (NSRange) rangeOfBytesFromSet:(NSData*)byteSet range:(NSRange)range {
    unsigned char min = 255;
    unsigned char max = 0;
    const unsigned char * bytes = (unsigned char*)byteSet.bytes;
    for (int i = 0; i < byteSet.length;++i) {
        unsigned char byte = bytes[i];
        if (byte < min) min = byte;
        if (byte > max) max = byte;
    }
    unsigned char * rangeBytes = (unsigned char*)self.bytes;

    int matchStart = NSNotFound;
    int matchLen = 0;
    for (int i = range.location; i < range.location + range.length; ++i) {
        int found = -1;
        if (rangeBytes[i] >= min || rangeBytes[i] <= max) {
            found = findByteIndex(rangeBytes[i], bytes, byteSet.length);
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
                return NSMakeRange(matchStart, matchLen);
            }
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

static const unsigned char hex_bytes_lower[16] = "0123456789abcdef";
static const unsigned char hex_bytes_upper[16] = "0123456789ABCDEF";

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
    int start = 0;
    int stop = findByteIndexFrom2(0, result.bytes, result.length, searchRange.location);
    while (stop >= 0 && start < result.length) {
        int gap = stop - start;
        if (MORE_COMPRESSION_TRACE) NSLog(@"start: %d stop %d gap %d", start, stop, gap);
        if (gap >= minSize) {
            NSRange done = compress(result, NSMakeRange(start, gap));
            start = done.location + done.length;
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"gap %d smaller than min %d", gap, minSize);
            start = stop;
        }
        if (start < result.length) {
            const unsigned char * bytes = result.bytes;
            if (MORE_COMPRESSION_TRACE) NSLog(@"check pos %d for 0", start);
            if (bytes[start] == 0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d is zero", start);
                unsigned char opcode = bytes[start+1];
                int skip = operationEncodedSize(opcode, bytes+start);
                if (MORE_COMPRESSION_TRACE) NSLog(@"skip:%d", skip);
                start += skip;
            } else {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d is not zero, searching for next zero as stop", start);
            }
            stop = findByteIndexFrom2(0, result.bytes, result.length, start);
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d has reached end", start);
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
        if (findByteIndex(0, entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
        unsigned char indexReference[2] = {0, i+1};
        [opcodes addObject:dataFromBytes(indexReference, 2)];
        
        if (MORE_COMPRESSION_TRACE) NSLog(@"\n");
        if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);

        result  = [result iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch range from %d size %d",range.location, range.length);
            if (entry.length <= range.length) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);
                NSRange found = [data rangeOfData:entry options:0 range:range];
                if (found.location != NSNotFound) {
                    NSData * refop = opcodes[i];
                    if (COMPRESSION_TRACE) NSLog(@"dictSearch found %@ at %d", [entry asciiString], found.location);
                    if (COMPRESSION_TRACE) NSLog(@"Dict: replacing %@ with %@",[[data subdataWithRange:found] asciiString], [refop asciiString] );
                    if (MORE_COMPRESSION_TRACE) NSLog(@"before=%@",[data asciiString]);
                    [data replaceBytesInRange:found withBytes:refop.bytes length:refop.length];
                    if (MORE_COMPRESSION_TRACE) NSLog(@"after=%@",[data asciiString]);
                    NSLog(@"match (reduced %d->%d):%@ (at %d)",found.length,refop.length, [entry asciiString], found.location);
                    return NSMakeRange(found.location, refop.length);
                }
            }
            return range;
        }];
    }
    return result;
}

-(NSData*) performHexCompression {
    NSData * result2 = self;
    NSData * hexCharsLower = dataFromBytes(hex_bytes_lower, 16);
    NSData * hexCharsUpper = dataFromBytes(hex_bytes_upper, 16);
    
    result2  = [result2 iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"hexSearch range from %d size %d",range.location, range.length);
        
        NSRange foundUUIDUpper = [data rangeOfUUIdStringInRange:range upperCase:YES];
        NSRange foundUUIDLower = [data rangeOfUUIdStringInRange:range upperCase:NO];
        NSRange foundUpper = [data rangeOfBytesFromSet:hexCharsUpper range:range];
        NSRange foundLower = [data rangeOfBytesFromSet:hexCharsLower range:range];
        
        NSRange found = minLocation(foundUUIDLower, minLocation(foundUUIDUpper,minLocation(foundLower,foundUpper)));
        
        if (found.location != NSNotFound) {
            if (found.length > 506) {
                found.length = 506; // limit chunk size to 253 binary bytes
            }
            if (found.length % 2 == 1) {
                found.length = found.length -1; // make even
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
                    if (MORE_COMPRESSION_TRACE) NSLog(@"dataWithCompressedHexStrings: Found %@ @ %d, len=%d", debugItem, found.location, found.length);
                }
                
                NSString * foundString = [NSString stringWithData:[data subdataWithRange:found] usingEncoding:NSUTF8StringEncoding];
                if (COMPRESSION_TRACE) NSLog(@"Found %@ %@ at pos %d",debugItem, foundString,found.location);
                BOOL quoted = NO;
                if (found.location > range.location && found.location+found.length+1 < data.length) {
                    // check for quotes
                    const unsigned char * bytes = data.bytes;
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
                
                if (COMPRESSION_TRACE) NSLog(@"Replacing:%@", [[data subdataWithRange:found] asciiString]);
                if (COMPRESSION_TRACE) NSLog(@"with:%@", [hexSequence asciiString]);
                
                [data replaceBytesInRange:found withBytes:hexSequence.bytes length:hexSequence.length];
                
                NSLog(@"%@ %@ %@ (reduced %d -> %d)", isUUID?@"uuid":@"hex", isUpperCase?@"uc":@"lc", quoted?@"quoted":@"", found.length, hexSequence.length);
                
                NSRange done = NSMakeRange(found.location, hexSequence.length);
                return done;
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
            NSData * base64Data = [NSData dataWithBase64EncodedString:base64String];
            if (base64Data == nil) {
                NSLog(@"#internal error, bad b64 decoding despite checked before");
                return range;
            }
            BOOL slashEscaped = NO;
            if ([base64String rangeOfString:@"\\/"].location != NSNotFound) {
                slashEscaped = YES;
            }
            
            NSMutableData * replacement = nil;
            if (base64Data.length<256) {
                unsigned char short_base64[3] = {0, slashEscaped ? BASE64_SHORT_SLASHESC : BASE64_SHORT, base64Data.length};
                replacement = mutableDataFromBytes(short_base64,3);
            } else if (base64Data.length < 65536) {
                unsigned char longer_base64[4] = {0, slashEscaped ? BASE64_LONGER_SLASHESC : BASE64_LONGER, base64Data.length/256, base64Data.length % 256};
                replacement = mutableDataFromBytes(longer_base64,4);
            } else {
                NSLog(@"#warning, b64 block > 64k, not compressing");
            }
            if (MORE_COMPRESSION_TRACE) {
                const unsigned char * bytes = replacement.bytes;
                int oplen = operationEncodedSize(bytes[1], bytes);
                NSLog(@"base64: encoded oplen = %d, base64Data.length=%d, msb=%d, lsb=%d", oplen, base64Data.length, bytes[2], bytes[3]);
            }
            NSRange replaceRange = NSMakeRange(found.location-1, found.length+2); // also replace quotes
            if (replacement != nil) {
                [replacement appendData:base64Data];
                
                if (COMPRESSION_TRACE) NSLog(@"b64:Replacing:%@", [[data subdataWithRange:found] asciiString]);
                if (COMPRESSION_TRACE) NSLog(@"with:%@", [replacement asciiString]);
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"before replacement:%@", [data asciiString]);
                
                [data replaceBytesInRange:replaceRange withBytes:replacement.bytes length:replacement.length];
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"after  replacement:%@", [data asciiString]);
                
                NSLog(@"base64 (reduced %d -> %d)", replaceRange.length, replacement.length);
                
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
    
    int start = findByteIndexFrom2(0, result.bytes, result.length, 0);
    while (start >= 0 && start != NSNotFound && start+1 < result.length ) {
        const unsigned char * bytes = result.bytes;
        unsigned char opcode = bytes[start+1];
        int compressedSize = operationEncodedSize(opcode, bytes+start);
        int opEnd = start + compressedSize -1;
        if (opEnd < result.length) {
            NSRange inserted = decompress(result, NSMakeRange(start, compressedSize));
            if (inserted.location == NSNotFound) {
                NSLog(@"iterateOverCompressedWithBlock: decompress failed at pos %d size %d",start,compressedSize);
                return nil;
            }
            start = inserted.location + inserted.length;
        } else {
            NSLog(@"iterateOverCompressedWithBlock: block too short at pos %d, required end = %d, actual size = %d",start,opEnd,result.length);
            return nil;
        }
        start = findByteIndexFrom2(0, result.bytes, result.length, start);
    }
    return result;
}

-(NSData*) performdecompressionWithDict:(NSArray*)dict {
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
        if (findByteIndex(0, entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
    }
    NSData * result;
    result = [self iterateOverCompressedWithBlock:^NSRange(NSMutableData *data, NSRange range) {
        const unsigned char * bytes = data.bytes;
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
    
    const unsigned char * bytes = compressedData.bytes;
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
        NSLog(@"#ERROR: hexReplacement: compressedData size matchmatch, expected %d, is %d", srcDataRange.location+srcDataSize,compressedData.length);
        return nil;
    }
    
    NSData * binaryData = [compressedData subdataWithRange:srcDataRange];

    NSString * hexString;
    if (isUUID) {
        NSUUID * uuid = [[NSUUID alloc] initWithUUIDBytes:binaryData.bytes];
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
    const unsigned char * bytes = compressedData.bytes;
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
        NSLog(@"#ERROR: base64Replacement: compressedData size matchmatch, expected %d, is %d", srcDataRange.location+srcDataSize,compressedData.length);
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


- (NSData *) compressWithDict:(NSArray*)dict {

    if (dict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    NSData * compressed = [self escaped];
    
    compressed = [compressed performDictCompressionWithDict:dict];

    int oldSize = compressed.length;
    compressed = [compressed performHexCompression];
    compressed = [compressed performBase64Compression];
    
    NSData * check = [compressed decompressWithDict:dict];
    
    if (oldSize != compressed.length) {
        NSLog(@"all hex/b64 (reduced %d->%d)",oldSize,compressed.length);
    }
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

- (NSString*)asciiString {
    NSMutableString * rep = [NSMutableString new];
    for (int i = 0; i < self.length; ++i) {
        unsigned char c = ((unsigned char*)self.bytes)[i];
        if (c >=0x20 && c < 0x7f) {
            [rep appendString:[NSString stringWithFormat:@"%c",c]];
        } else {
            [rep appendString:[NSString stringWithFormat:@"<%d>",c]];
        }
    }
    return rep;
}

- (NSData *) decompressWithDict:(NSArray*)dict {
    if (dict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    if (COMPRESSION_TRACE) NSLog(@"DECOMPRESSING");
    if (COMPRESSION_TRACE) NSLog(@"%@", [self asciiString]);
    
    
    NSData * uncompressed = [self performdecompressionWithDict:dict];
        
/*
    NSData * uncompressed = [NSData dataWithData:self];
    uncompressed = [uncompressed dataWithUncompressedBase64Strings];
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after base64:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
    
    uncompressed = [uncompressed dataWithUncompressedHexStrings];
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after hex:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
    
    for (int i = 0; i < dict.count;++i) {
        NSData * entry = dict[i];
        if ([entry isKindOfClass:[NSString class]]) {
            // convert string from dict to data
            entry = [(NSString*)entry dataUsingEncoding:NSUTF8StringEncoding];
        }
        unsigned char indexReference[2];
        indexReference[0] = 0;
        indexReference[1] = i + 1;
        uncompressed = [uncompressed dataByReplacingOccurrencesOfData:dataFromBytes(indexReference, 2) withData:entry];
    }
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after dict:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
 */
    uncompressed = [uncompressed unescaped];
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after unescape:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
    return uncompressed;
}


@end
