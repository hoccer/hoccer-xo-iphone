//
//  HXOTheme.h
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageSection.h"

@interface HXOTheme : NSObject

+ (id) theme;

@property (nonatomic,readonly) UIColor * navigationBarBackgroundColor;
@property (nonatomic,readonly) UIColor * navigationBarTintColor;
@property (nonatomic,readonly) UIColor * ledColor;
@property (nonatomic,readonly) UIColor * tableSeparatorColor;

@property (nonatomic,readonly) UIFont *   smallTextFont;
@property (nonatomic,readonly) UIFont *   smallBoldTextFont;
@property (nonatomic,readonly) UIColor *  lightTextColor;


- (UIColor*) messageBackgroundColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageTextColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageFooterTextColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageLinkColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentTitleColorForScheme:    (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentSubtitleColorForScheme: (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentIconTintColorForScheme: (HXOBubbleColorScheme) scheme;

- (void) setupTheming;

@end
