//
//  NSData+DictCompression.h
//  HoccerXO
//
//  Created by PM on 17.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (DictCompression)

- (NSData *) compressWithDict:(NSArray*)dict;

@end
