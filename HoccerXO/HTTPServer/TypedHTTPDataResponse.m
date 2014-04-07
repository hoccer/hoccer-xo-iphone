//
//  TypedHTTPDataResponse.m
//  HoccerXO
//
//  Created by PM on 02.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "TypedHTTPDataResponse.h"

@implementation TypedHTTPDataResponse

- (NSDictionary *)httpHeaders {
    if (self.mimeType != nil) {
        /*
        NSDictionary * headers = @{@"Content-Disposition": contentDisposition,
                                   @"Content-Type"       : self.mimeType,
                                   @"Content-Length" : [self contentSize].stringValue};
         */
        return @{@"Content-Type" : self.mimeType};
    }
    return nil;
}

@end
