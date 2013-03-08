//
//  AssetStore.h
//  HoccerTalk
//
//  Created by David Siegel on 08.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AssetStore : NSObject

+ (UIImage*) stretchableImageNamed: (NSString*) name withLeftCapWidth: (NSUInteger) w topCapHeight: (NSUInteger) h;

@end
