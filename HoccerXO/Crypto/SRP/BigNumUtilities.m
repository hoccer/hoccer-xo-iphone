//
//  BignNumUtilities.m
//  VisualHash
//
//  Created by David Siegel on 10.03.14.
//  Copyright (c) 2014 David Siegel. All rights reserved.
//

#import "BigNumUtilities.h"


NSString * DSNSStringFromBIGNUM(BIGNUM * a, unsigned radix) {
    if ( ! a) { return nil; }
    const char * cstr;
    switch (radix) {
        case 10: cstr = BN_bn2dec(a); break;
        case 16: cstr = BN_bn2hex(a); break;
        default:
            NSLog(@"unsupported radix %u", radix);
            cstr = NULL;
    }
    NSString * result = [NSString stringWithCString: cstr encoding: NSASCIIStringEncoding];
    free((void*)cstr);
    return result;
}

BIGNUM * DSBIGNUMFromNSData(NSData * data) {
    BIGNUM * a = NULL;
    if (data) {
        a = BN_new();
        if (a) {
            BN_bin2bn(data.bytes, (int)data.length, a);
        }
    }
    return a;
}

BIGNUM * DSBIGNUMFromNSString(NSString * string, unsigned radix) {
    BIGNUM * a = NULL;
    switch (radix) {
        case 10: BN_dec2bn(&a, [string cStringUsingEncoding: NSASCIIStringEncoding]); break;
        case 16: BN_hex2bn(&a, [string cStringUsingEncoding: NSASCIIStringEncoding]); break;
        default:
            NSLog(@"unsupported radix %u", radix);
    }
    return a;
}

@implementation NSData (BIGNUM)

+ (NSData*) dataWithBIGNUM: (BIGNUM*) a {
    if ( ! a) { return nil; }
    NSMutableData * data = [NSMutableData dataWithLength: BN_num_bytes(a)];
    if (data) {
        BN_bn2bin(a, data.mutableBytes);
    }
    return data;
}

@end
