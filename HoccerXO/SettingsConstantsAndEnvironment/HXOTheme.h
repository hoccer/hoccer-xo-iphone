//
//  HXOTheme.h
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HXOTheme : NSObject

+ (id) theme;

@property (nonatomic,readonly) UIColor * navigationBarTintColor;

- (void) setupAppearanceProxies;

@end
