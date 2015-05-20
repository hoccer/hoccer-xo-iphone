//
//  NSData+NSInputStream.m
//  HoccerXO
//
//  Created by pavel on 22/09/14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//


#import "NSData+NSInputStream.h"

#define BUFSIZE 65536U

@implementation NSData (NSInputStream)
+(NSData *)dataWithContentsOfStream:(NSInputStream *)input initialCapacity:(NSUInteger)capacity error:(NSError **)error {
    
    NSUInteger bufferSize = 8192;
    NSInteger read = 0;
    uint8_t     *buff = (uint8_t *)malloc(sizeof(uint8_t)*bufferSize);
    
    [input open];
    
    NSMutableData* result = capacity == NSUIntegerMax ? [NSMutableData data] : [NSMutableData dataWithCapacity:capacity];
    
    do {
        read = [input read:buff maxLength:bufferSize];
        //NSLog(@"computeMAC: read %d bytes", read);
        if (read > 0) {
            [result appendBytes:buff length:read];
        }
    } while (read > 0);
    
    free(buff);
    
    if (read < 0) {
        if (error != nil) {
            *error = input.streamError;
        }
        [input close];
        return result;
    }
    [input close];
    return result;
    
}
@end
