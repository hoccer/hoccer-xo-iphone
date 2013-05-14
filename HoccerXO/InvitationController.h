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

#define ActionSheet UIActionSheet
#define ActionSheetDelegate UIActionSheetDelegate

@interface InvitationController : NSObject <ActionSheetDelegate,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

+ (id) sharedInvitationController;

- (void) presentWithViewController: (UIViewController*) viewController;

@end
