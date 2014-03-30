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

+ (HXOTheme*) theme;

@property (nonatomic,readonly) UIColor * navigationBarBackgroundColor;
@property (nonatomic,readonly) UIColor * navigationBarTintColor;
@property (nonatomic,readonly) UIColor * ledColor;
@property (nonatomic,readonly) UIColor * tableSeparatorColor;
@property (nonatomic,readonly) UIColor * cellAccessoryColor;
@property (nonatomic,readonly) UIColor * messageFieldBackgroundColor;
@property (nonatomic,readonly) UIColor * messageFieldBorderColor;

@property (nonatomic,readonly) UIColor * defaultAvatarColor;
@property (nonatomic,readonly) UIColor * defaultAvatarBackgroundColor;


@property (nonatomic,readonly) UIFont *   messageFont;
@property (nonatomic,readonly) UIFont *   titleFont;
@property (nonatomic,readonly) UIFont *   smallTextFont;
@property (nonatomic,readonly) UIFont *   smallBoldTextFont;
@property (nonatomic,readonly) UIColor *  lightTextColor;
@property (nonatomic,readonly) UIColor *  smallBoldTextColor;

- (UIColor*) messageBackgroundColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageTextColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageFooterTextColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageLinkColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentTitleColorForScheme:    (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentSubtitleColorForScheme: (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentIconTintColorForScheme: (HXOBubbleColorScheme) scheme;

- (void) setupTheming;

@end
