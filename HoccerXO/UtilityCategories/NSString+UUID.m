//
//  NSString+UUID.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NSString+UUID.h"

@implementation NSString (UUID)

+ (NSString*) stringWithUUID {
    CFUUIDRef uuidObject = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidStr = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuidObject));
    CFRelease(uuidObject);
    return uuidStr;
}

@end
