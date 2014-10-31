//
//  InviteController.h
//  HoccerXO
//
//  Created by David Siegel on 31.10.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MessageUI/MessageUI.h>

#import "PeopleMultiPickerViewController.h"

@interface InviteController : NSObject <PeopleMultiPickerDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

- (void) invitePeople: (UIViewController*) view;

@end
