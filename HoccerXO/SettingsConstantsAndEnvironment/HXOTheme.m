//
//  HXOTheme.m
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTheme.h"
#import "UIColor+HSBUtilities.h"
#import "UIColor+HexUtilities.h"
#import "HXOThemedNavigationController.h"
#import "LabelWithLED.h"

static HXOTheme * _currentTheme;

@implementation HXOTheme

#pragma mark - Applicationwide Colors

- (UIColor*) tintColor {
    return [UIColor colorWithHexString: @"#0079FF"];
}

- (UIColor*) navigationBarBackgroundColor {
    return [UIColor colorWithHexString: @"#39C0B3"];
}

- (UIColor*) navigationBarTintColor {
    return [UIColor whiteColor];
}

- (UIColor*) tableSeparatorColor {
    return [UIColor colorWithHexString: @"#D"];
}

- (UIColor*) ledColor {
    return [UIColor redColor];
}

- (UIColor*) cellAccessoryColor {
    return [UIColor colorWithHexString:@"#20B4A4"];
}

- (UIColor*) messageFieldBackgroundColor {
    return [UIColor whiteColor];
}

- (UIColor*) messageFieldBorderColor {
    return [UIColor colorWithHexString: @"#D0"];
}

- (UIColor*) defaultAvatarColor {
    return [UIColor colorWithHexString: @"#9BA2B1"];
}

- (UIColor*) defaultAvatarBackgroundColor {
    return [UIColor colorWithHexString: @"#DADDE6"];
}
#pragma mark - Message Color Schemes

- (UIColor*) messageBackgroundColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:   return [UIColor colorWithHexString: @"#E6E7EB"];
        case HXOBubbleColorSchemeSuccess:    return [UIColor colorWithHexString: @"#39C0B3"];
        case HXOBubbleColorSchemeInProgress: return [UIColor colorWithHexString: @"#B8CCCA"];
        case HXOBubbleColorSchemeFailed:     return [UIColor colorWithHexString: @"#BD3935"];
    }
}

- (UIColor*) messageTextColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor blackColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

- (UIColor*) messageFooterTextColorForScheme: (HXOBubbleColorScheme) scheme {
    return [[self messageBackgroundColorForScheme: scheme] darken];
}

- (UIColor*) messageLinkColorForScheme: (HXOBubbleColorScheme) scheme {
    return [UIColor blueColor];
}

- (UIColor*) messageAttachmentTitleColorForScheme: (HXOBubbleColorScheme) scheme {
    return [self messageTextColorForScheme: scheme];
}

- (UIColor*) messageAttachmentSubtitleColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor lightGrayColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

- (UIColor*) messageAttachmentIconTintColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [self tintColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

#pragma mark - Fonts & Text Colors

- (UIFont*) messageFont {
    return [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
}

- (UIFont*) titleFont {
    return [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
}

- (NSDictionary*) smallTextFontSizes {
    return @{  UIContentSizeCategoryExtraSmall:                          @(9.0)
               , UIContentSizeCategorySmall:                             @(10.0)
               , UIContentSizeCategoryMedium:                            @(11.0)
               , UIContentSizeCategoryLarge:                             @(12.0)
               , UIContentSizeCategoryExtraLarge:                        @(13.0)
               , UIContentSizeCategoryExtraExtraLarge:                   @(14)
               , UIContentSizeCategoryExtraExtraExtraLarge:              @(15)

               , UIContentSizeCategoryAccessibilityMedium:               @(12)
               , UIContentSizeCategoryAccessibilityLarge:                @(13)
               , UIContentSizeCategoryAccessibilityExtraLarge:           @(14)
               , UIContentSizeCategoryAccessibilityExtraExtraLarge:      @(16)
               , UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: @(18)
               };
}

- (NSDictionary*) smallBoldTextFontSizes {
    return @{  UIContentSizeCategoryExtraSmall:                          @(8.0)
               , UIContentSizeCategorySmall:                             @(9.0)
               , UIContentSizeCategoryMedium:                            @(10.0)
               , UIContentSizeCategoryLarge:                             @(11.0)
               , UIContentSizeCategoryExtraLarge:                        @(12.0)
               , UIContentSizeCategoryExtraExtraLarge:                   @(13)
               , UIContentSizeCategoryExtraExtraExtraLarge:              @(14)

               , UIContentSizeCategoryAccessibilityMedium:               @(12)
               , UIContentSizeCategoryAccessibilityLarge:                @(13)
               , UIContentSizeCategoryAccessibilityExtraLarge:           @(14)
               , UIContentSizeCategoryAccessibilityExtraExtraLarge:      @(16)
               , UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: @(18)
               };
}

- (UIColor*) lightTextColor {
    return [UIColor colorWithHexString:@"#A8AFB8"];
}

- (UIColor*) smallBoldTextColor {
    return [UIColor colorWithHexString:@"#9FA3AC"];
}


#pragma mark - No settings beyond this point

@synthesize smallTextFont = _smallTextFont;
- (UIFont*) smallTextFont {
    CGFloat size = [self.smallTextFontSizes[[UIApplication sharedApplication].preferredContentSizeCategory] doubleValue];
    if (_smallTextFont.pointSize != size) {
        _smallTextFont = [UIFont systemFontOfSize: size];
    }
    return _smallTextFont;
}

@synthesize smallBoldTextFont = _smallBoldTextFont;
- (UIFont*) smallBoldTextFont {
    CGFloat size = [self.smallBoldTextFontSizes[[UIApplication sharedApplication].preferredContentSizeCategory] doubleValue];
    if (_smallBoldTextFont.pointSize != size) {
        _smallBoldTextFont = [UIFont boldSystemFontOfSize: size];
    }
    return _smallBoldTextFont;
}



+ (void) initialize {
    _currentTheme = [[HXOTheme alloc] init];
}

+ (HXOTheme*) theme {
    return _currentTheme;
}

- (void) setupTheming {
    [UIApplication sharedApplication].delegate.window.tintColor = [self tintColor];
    
    id navigationBarAppearance = [UINavigationBar appearanceWhenContainedIn: [HXOThemedNavigationController class], nil];
    [navigationBarAppearance setBarTintColor: self.navigationBarBackgroundColor];
    [navigationBarAppearance setBarStyle:     UIBarStyleBlackTranslucent];
    [navigationBarAppearance setTintColor:    self.navigationBarTintColor];
    [navigationBarAppearance setTitleTextAttributes: @{NSForegroundColorAttributeName: [UIColor whiteColor]}];
    
    [[LabelWithLED appearance] setLedColor: self.ledColor];
}

@end
