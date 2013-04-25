//
//  InvitationController.h
//  HoccerTalk
//
//  Created by David Siegel on 25.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MessageUI/MFMailComposeViewController.h>
#import <MessageUI/MessageUI.h>

@interface InvitationController : NSObject <UIActionSheetDelegate,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

+ (id) sharedInvitationController;

- (void) presentWithViewController: (UIViewController*) viewController;

@end
