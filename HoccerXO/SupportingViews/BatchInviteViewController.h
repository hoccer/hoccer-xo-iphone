//
//  BatchInviteViewController.h
//  HoccerXO
//
//  Created by David Siegel on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <MessageUI/MessageUI.h>

#import "HXOThemedNavigationController.h"

#import "PeopleMultiPickerViewController.h"

@interface BatchInviteViewController : HXOThemedNavigationController <PeopleMultiPickerDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic,assign) PeoplePickerMode mode;

@end
