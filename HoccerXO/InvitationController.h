//
//  InvitationController.h
//  HoccerXO
//
//  Created by David Siegel on 25.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MessageUI/MFMailComposeViewController.h>
#import <MessageUI/MessageUI.h>
#import "HXOActionSheet.h"

#define USE_HXO_ACTION_SHEET

#ifdef USE_HXO_ACTION_SHEET
#   define ActionSheet HXOActionSheet
#   define ActionSheetDelegate HXOActionSheetDelegate
#else
#   define ActionSheet UIActionSheet
#   define ActionSheetDelegate UIActionSheetDelegate
#endif

@interface InvitationController : NSObject <ActionSheetDelegate,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

+ (id) sharedInvitationController;

- (void) presentWithViewController: (UIViewController*) viewController;

@end
