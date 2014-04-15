//
//  HXOTheme.m
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOUI.h"
#import "UIColor+HSBUtilities.h"
#import "UIColor+HexUtilities.h"
#import "HXOThemedNavigationController.h"
#import "LabelWithLED.h"
#import "UIAlertView+BlockExtensions.h"
#import "HXOHyperLabel.h"

const CGFloat kHXOGridSpacing = 8;
const CGFloat kHXOCellPadding = 2 * kHXOGridSpacing;

const CGFloat kHXOChatAvatarSize = 5 * kHXOGridSpacing;
const CGFloat kHXOListAvatarSize = 6 * kHXOGridSpacing;
const CGFloat kHXOProfileAvatarSize = 17 * kHXOGridSpacing;
const CGFloat kHXOProfileAvatarPadding = 3 * kHXOGridSpacing;


static HXOUI * _currentTheme;

@implementation HXOUI

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
    return [UIColor colorWithHexString: @"#8EC12C"];
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

- (UIColor*) blockSignColor {
    return [UIColor colorWithHexString: @"#ffffffb0"];
}

-(UIColor*) avatarBadgeColor {
    return [UIColor colorWithHexString:@"#f00"];
}

-(UIColor*) avatarBadgeBorderColor {
    return [UIColor colorWithHexString:@"#f"];
}

- (UIColor*) avatarOnlineLedColor {
    return [UIColor colorWithHexString: @"#8EC12C"];
}

- (UIColor*) verifiedKeyColor {
    return [UIColor colorWithHexString: @"#3ABB7D"];
}

- (UIColor*) unverifiedKeyColor {
    return [UIColor yellowColor];
}

- (UIColor*) mistrustedKeyColor {
    return [UIColor redColor];
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

               , UIContentSizeCategoryAccessibilityMedium:               @(16)
               , UIContentSizeCategoryAccessibilityLarge:                @(17)
               , UIContentSizeCategoryAccessibilityExtraLarge:           @(18)
               , UIContentSizeCategoryAccessibilityExtraExtraLarge:      @(19)
               , UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: @(20)
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

               , UIContentSizeCategoryAccessibilityMedium:               @(15)
               , UIContentSizeCategoryAccessibilityLarge:                @(16)
               , UIContentSizeCategoryAccessibilityExtraLarge:           @(17)
               , UIContentSizeCategoryAccessibilityExtraExtraLarge:      @(18)
               , UIContentSizeCategoryAccessibilityExtraExtraExtraLarge: @(19)
               };
}

- (UIColor*) lightTextColor {
    return [UIColor colorWithHexString:@"#A8AFB8"];
}

- (UIColor*) smallBoldTextColor {
    return [UIColor colorWithHexString:@"#9FA3AC"];
}

- (UIColor*) footerTextLinkColor {
    return [self.smallBoldTextColor darken];
}
- (UIColor*) destructiveTextColor {
    return [UIColor colorWithHexString: @"#f00"];
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
    if (self == [HXOUI class]) {
        _currentTheme = [[HXOUI alloc] init];
    }
}

+ (HXOUI*) theme {
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


#pragma mark - Value Formatters

+ (NSString*) formatKeyFingerprint: (NSString*) rawKeyIdString {
    NSMutableArray * fingerprint = [NSMutableArray array];
    for (int i = 0; i < rawKeyIdString.length; i += 2) {
        [fingerprint addObject: [rawKeyIdString substringWithRange: NSMakeRange(i, 2)]];
    }
    return [fingerprint componentsJoinedByString:@":"];
}

#pragma mark - Standard Dialogs :-/

+ (void) showErrorAlertWithMessage: (NSString *) message withTitle:(NSString *) title {

    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title, nil)
                                                     message: NSLocalizedString(message, nil)
                                                    delegate: nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

+ (void) showErrorAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title {
    dispatch_async(dispatch_get_main_queue(), ^{
        [HXOUI showErrorAlertWithMessage:message withTitle:title];
    });
}

+ (void) showAlertWithMessage: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument {

    NSString * localizedMessage = NSLocalizedString(message, "");
    NSString * fullMessage = [NSString stringWithFormat:localizedMessage, argument];

    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(title, nil)
                                                     message: NSLocalizedString(fullMessage, nil)
                                                    delegate: nil
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

+ (void) showAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument {
    dispatch_async(dispatch_get_main_queue(), ^{
        [HXOUI showAlertWithMessage:message withTitle:title withArgument:argument];
    });
}

+ (void) enterStringAlert: (NSString *) message withTitle:(NSString *)title withPlaceHolder:(NSString *)placeholder onCompletion:(HXOStringEntryCompletion)completionBlock {
    HXOAlertViewCompletionBlock completion = ^(NSUInteger buttonIndex, UIAlertView* alertView) {
        NSString * enteredText;
        switch (buttonIndex) {
            case 0:
                completionBlock(nil);
                break;
            case 1:
                enteredText = [[alertView textFieldAtIndex:0] text];
                if (enteredText.length > 0) {
                    completionBlock(enteredText);
                } else {
                    completionBlock(nil);
                }
                break;
        }
    };
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                            completionBlock: completion
                                          cancelButtonTitle:NSLocalizedString(@"cancel",nil)
                                          otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField * alertTextField = [alert textFieldAtIndex:0];
    alertTextField.keyboardType = UIKeyboardTypeDefault;
    alertTextField.placeholder = placeholder;
    [alert show];
}

+ (UIActionSheet*) actionSheetWithTitle:(NSString *)title completionBlock:(HXOActionSheetCompletionBlock)completion cancelButtonTitle:(NSString *)cancelTitle destructiveButtonTitle:(NSString *)destructiveTitle otherButtonTitles: (NSString*) otherTitles, ... {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: title
                                                 completionBlock: completion
                                               cancelButtonTitle: nil
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: nil];




	if (sheet) {
		if (destructiveTitle) {
			sheet.destructiveButtonIndex = [sheet addButtonWithTitle: destructiveTitle];
		}

		id eachObject;
		va_list argumentList;
		if (otherTitles) {
			[sheet addButtonWithTitle: otherTitles];
			va_start(argumentList, otherTitles);
			while ((eachObject = va_arg(argumentList, id))) {
				[sheet addButtonWithTitle:eachObject];
			}
			va_end(argumentList);
		}

		if (cancelTitle) {
			sheet.cancelButtonIndex = [sheet addButtonWithTitle: cancelTitle];
		}
	}

    // Apply xo settings
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;

    return sheet;
}

NSAttributedString * HXOLocalizedStringWithLinks(NSString * key, NSString * comment) {
    NSError * error;
    NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern: @"\\[([^\\]]+)\\]\\(([^)]+)\\)" options: 0 error: &error];
    NSMutableString * text =  [NSMutableString stringWithString: NSLocalizedString(key, comment)];
    NSArray *results = [regex matchesInString: text options:kNilOptions range:NSMakeRange(0, text.length)];
    NSInteger offset = 0;
    NSMutableArray * linkRanges = [NSMutableArray array];
    NSMutableArray * urls = [NSMutableArray array];
    for (NSTextCheckingResult *result in results) {
        NSRange resultRange = [result range];
        resultRange.location += offset;
        NSString* match = [regex replacementStringForResult: result
                                                   inString: text
                                                     offset: offset
                                                   template: @"$1"];

        NSRange linkRange = [result rangeAtIndex: 1];
        linkRange.location += offset - 1; // eh ... compensate the opening bracket we are about to loose :-/

        NSRange urlRange = [result rangeAtIndex: 2];
        urlRange.location += offset;

        [linkRanges addObject: [NSValue valueWithRange: linkRange]];
        [urls addObject: [text substringWithRange: urlRange]];

        [text replaceCharactersInRange: resultRange withString: match];

        offset += [match length] - resultRange.length;
    }
    NSMutableAttributedString * result = [[NSMutableAttributedString alloc] initWithString: text attributes: nil];
    for (int i = 0; i < urls.count; ++i) {
        NSRange link = [linkRanges[i] rangeValue];
        NSString * url = urls[i];
        NSDictionary * attributes = @{kHXOLinkAttributeName: url};
        [result setAttributes: attributes range: link];
    }
    return result;
}

+ (NSString*) messageCountBadgeText: (NSUInteger) count {
    return count == 0 ? nil : count > 99 ? @">99" : @(count).stringValue;
}

@end
