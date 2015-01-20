//
//  HXOTheme.h
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageSection.h"
#import "UIAlertView+BlockExtensions.h"
#import "UIActionSheet+BlockExtensions.h"

// When used in ObjC++ files (InvitationCodeViewController.mm) we need to
// declare C linkage on free functions to disable C++ name mangeling and avoid
// linker errors down the road.
#ifdef __cplusplus
# define HXO_OBJCPP_LINKAGE extern "C"
#else
# define HXO_OBJCPP_LINKAGE
#endif

FOUNDATION_EXPORT const CGFloat kHXOGridSpacing;
FOUNDATION_EXPORT const CGFloat kHXOCellPadding;

FOUNDATION_EXPORT const CGFloat kHXOListAvatarSize;
FOUNDATION_EXPORT const CGFloat kHXOChatAvatarSize;
FOUNDATION_EXPORT const CGFloat kHXOProfileAvatarSize;
FOUNDATION_EXPORT const CGFloat kHXOProfileAvatarPadding;

typedef void(^HXOActionSheetCompletionBlock)(NSUInteger buttonIndex, UIActionSheet * actionSheet);
typedef void(^HXOAlertViewCompletionBlock)(NSUInteger buttonIndex, UIAlertView * alertView);
typedef void(^HXOStringEntryCompletion)(NSString* entry);

HXO_OBJCPP_LINKAGE NSAttributedString * HXOLocalizedStringWithLinks(NSString * key, NSString * comment);

@interface HXOUI : NSObject

+ (HXOUI*) theme;

@property (nonatomic, readonly) UIColor * tintColor;
@property (nonatomic, readonly) UIColor * navigationBarBackgroundColor;
@property (nonatomic, readonly) UIColor * navigationBarTintColor;
@property (nonatomic, readonly) UIColor * ledColor;
@property (nonatomic, readonly) UIColor * tableSeparatorColor;
@property (nonatomic, readonly) UIColor * tablePlaceholderTextColor;
@property (nonatomic, readonly) UIColor * cellAccessoryColor;
@property (nonatomic, readonly) UIColor * messageFieldBackgroundColor;
@property (nonatomic, readonly) UIColor * messageFieldBorderColor;

@property (nonatomic, readonly) UIColor * defaultAvatarColor;
@property (nonatomic, readonly) UIColor * defaultAvatarBackgroundColor;
@property (nonatomic, readonly) UIColor * blockSignColor;
@property (nonatomic, readonly) UIColor * avatarBadgeColor;
@property (nonatomic, readonly) UIColor * avatarBadgeBorderColor;
@property (nonatomic, readonly) UIColor * avatarOnlineLedColor;
@property (nonatomic, readonly) UIColor * avatarOnlineInBackgroundLedColor;

@property (nonatomic, readonly) UIFont  * messageFont;
@property (nonatomic, readonly) UIFont  * titleFont;
@property (nonatomic, readonly) UIFont  * smallTextFont;
@property (nonatomic, readonly) UIFont  * smallBoldTextFont;
@property (nonatomic, readonly) UIColor * lightTextColor;
@property (nonatomic, readonly) UIColor * smallBoldTextColor;
@property (nonatomic, readonly) UIColor * footerTextLinkColor;
@property (nonatomic, readonly) UIColor * destructiveTextColor;

@property (nonatomic, readonly) UIColor * verifiedKeyColor;
@property (nonatomic, readonly) UIColor * unverifiedKeyColor;
@property (nonatomic, readonly) UIColor * mistrustedKeyColor;

- (UIColor*) messageBackgroundColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageTextColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageFooterTextColorForScheme:         (HXOBubbleColorScheme) scheme;
- (UIColor*) messageLinkColorForScheme:               (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentTitleColorForScheme:    (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentSubtitleColorForScheme: (HXOBubbleColorScheme) scheme;
- (UIColor*) messageAttachmentIconTintColorForScheme: (HXOBubbleColorScheme) scheme;

- (void) setupTheming;

+ (UIActionSheet*) actionSheetWithTitle: (NSString*) title completionBlock: (HXOActionSheetCompletionBlock) completion cancelButtonTitle: (NSString*) cancelTitle destructiveButtonTitle: (NSString*) destructiveTitle otherButtonTitles: (NSString*) otherTitles, ... ;

+ (UIActionSheet*) actionSheetWithTitle: (NSString*) title completionBlock: (HXOActionSheetCompletionBlock) completion cancelButtonTitle: (NSString*) cancelTitle destructiveButtonTitle: (NSString*) destructiveTitle otherButtonTitleArray: (NSArray*) otherTitles;


+ (NSString*) formatKeyFingerprint: (NSString*) rawKeyIdString;
+ (void) showErrorAlertWithMessage: (NSString *) message withTitle:(NSString *) title;
+ (void) showErrorAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title;

+ (void) showAlertWithMessage: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument;
+ (void) showAlertWithMessageAsync: (NSString *) message withTitle:(NSString *) title withArgument:(NSString*) argument;

+ (void) enterStringAlert: (NSString *) message withTitle:(NSString *)title withPlaceHolder:(NSString *)placeholder onCompletion:(HXOStringEntryCompletion)completionBlock;

+ (NSString*) messageCountBadgeText: (NSUInteger) count;

@end
