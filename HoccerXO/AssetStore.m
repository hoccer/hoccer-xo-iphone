//
//  AssetStore.m
//  HoccerXO
//
//  Created by David Siegel on 08.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AssetStore.h"

static AssetStore *sharedStore;

@interface AssetStore ()

@property (nonatomic,strong) NSMutableDictionary* store;

@end

@implementation AssetStore

+ (void)initialize {
    static BOOL initialized = NO;
    if(!initialized)
    {
        initialized = YES;
        sharedStore = [[AssetStore alloc] init];
    }
}

- (id) init {
    self = [super init];
    if (self != nil) {
        self.store = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+ (UIImage*) stretchableImageNamed: (NSString*) name withLeftCapWidth: (NSUInteger) w topCapHeight: (NSUInteger) h {
    return [sharedStore stretchableImageNamed: name withLeftCapWidth: w topCapHeight: h];
}

- (UIImage*) stretchableImageNamed: (NSString*) name withLeftCapWidth: (NSUInteger) w topCapHeight: (NSUInteger) h {
    NSString * key = [NSString stringWithFormat: @"%@-w:%d-h:%d", name, w, h];
    UIImage * image = self.store[key];
    if (image == nil) {
        image = [[UIImage imageNamed: name] stretchableImageWithLeftCapWidth: w topCapHeight: h];
        self.store[key] = image;
    }
    return image;
}

@end
