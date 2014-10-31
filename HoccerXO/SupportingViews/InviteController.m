//
//  InviteController.m
//  HoccerXO
//
//  Created by David Siegel on 31.10.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "InviteController.h"
#import "HXOUI.h"
#import "HXOBackend.h"
#import "Environment.h"
#import "HXOUserDefaults.h"
#import "AppDelegate.h"
#import "InvitationCodeViewController.h"
#import "HXOThemedNavigationController.h"

@interface InviteController ()

@property (nonatomic, readonly) ABAddressBookRef               addressBook;
@property (nonatomic, strong)   NSMutableArray               * coolingPond;
@property (nonatomic, readonly) InvitationCodeViewController * invitationCodeViewController;

@end

@implementation InviteController

- (id) init {
    self = [super init];
    if (self) {
        self.coolingPond = [NSMutableArray array];
    }
    return self;
}

- (void) invitePeople: (UIViewController*) vc {
    NSMutableArray * actions = [NSMutableArray array];
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            dispatch_async(dispatch_get_main_queue(), actions[buttonIndex]);
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"invite_option_sheet_title", @"Actionsheet Title")
                                        completionBlock: completion
                                      cancelButtonTitle: nil
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: nil];


    if ([MFMessageComposeViewController canSendText]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_sms_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteByMessage: PeoplePickerModeText withViewController: vc]; }];
    }
    if ([MFMailComposeViewController canSendMail]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_mail_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteByMessage: PeoplePickerModeMail withViewController: vc]; }];
    }
    [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_code_btn_title",@"Invite Actionsheet Button Title")];
    [actions addObject: ^() { [self inviteByCode: vc]; }];

    sheet.cancelButtonIndex = [sheet addButtonWithTitle: NSLocalizedString(@"cancel", nil)];

    [sheet showInView: vc.view];
}

- (void) inviteByCode: (UIViewController*) vc {
    [vc presentViewController: [[HXOThemedNavigationController alloc] initWithRootViewController: self.invitationCodeViewController] animated: YES completion: nil];
}

- (void) inviteByMessage: (PeoplePickerMode) mode withViewController: (UIViewController*) viewController {

    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    void(^presentViewController)(UIViewController*) = ^(UIViewController * vc) {
        [viewController presentViewController: vc animated: YES completion: nil];
    };
    if (status == kABAuthorizationStatusNotDetermined) {
        ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error) {
            [self firstViewController: granted mode: mode completion: presentViewController];
        });
    } else {
        [self firstViewController: status  == kABAuthorizationStatusAuthorized mode: mode completion: presentViewController];
    }
}


- (void) firstViewController: (BOOL) addressBookPermitted mode: (PeoplePickerMode) mode completion: (void(^)(UIViewController*)) completion {
    if (addressBookPermitted) {
        PeopleMultiPickerViewController * vc = [[PeopleMultiPickerViewController alloc] initWithStyle: UITableViewStylePlain];
        vc.delegate = self;
        vc.mode = mode;
        completion([[HXOThemedNavigationController alloc] initWithRootViewController: vc]);
    } else {
        [self composeViewController: mode recipients: @[] completion: completion];
    }
}

- (void) composeViewController: (PeoplePickerMode) mode recipients: (NSArray*) recipients completion: (void(^)(UIViewController*)) completion {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        UIViewController * vc;
        switch (mode) {
            case PeoplePickerModeMail: {
                MFMailComposeViewController * mailView = [[MFMailComposeViewController alloc] init];
                vc = mailView;
                mailView.mailComposeDelegate = self;
                [mailView setSubject:  NSLocalizedString(@"invite_mail_subject", nil)];
                [mailView setBccRecipients: recipients];

                NSString * body = NSLocalizedString(@"invite_mail_body", nil);
                body = [NSString stringWithFormat: body, [self inviteURL: token]];
                [mailView setMessageBody: body isHTML: NO];
            } break;
            case PeoplePickerModeText: {
                MFMessageComposeViewController * messageView = [[MFMessageComposeViewController alloc] init];
                vc = messageView;
                messageView.messageComposeDelegate = self;
                messageView.recipients = recipients;

                NSString * smsText = NSLocalizedString(@"invite_sms_text", nil);
                messageView.body = [NSString stringWithFormat: smsText, [self inviteURL: token], [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName]];
            } break;
        }
        [self.coolingPond insertObject: vc atIndex: 0];
        if (self.coolingPond.count > 10) {
            [self.coolingPond removeLastObject];
        }
        completion(vc);
    }];
}

- (NSString*) inviteURL: (NSString*) token {
    NSString * inviteServer = [[Environment sharedEnvironment] inviteServer];
    return [NSString stringWithFormat: @"%@/%@", inviteServer, token];
}

#pragma - PeopleMultiPickerDelegate

- (void) peopleMultiPicker: (PeopleMultiPickerViewController*) picker didFinishWithSelection: (NSArray*) selection {
    NSMutableArray * recipients = [NSMutableArray array];
    for (NSDictionary * item in selection) {
        ABMultiValueRef multiValue = ABRecordCopyValue((__bridge ABRecordRef)(item[@"person"]), [item[@"property"] intValue]);
        CFIndex valueIndex = ABMultiValueGetIndexForIdentifier(multiValue, [item[@"identifier"] intValue]);
        [recipients addObject: CFBridgingRelease(ABMultiValueCopyValueAtIndex(multiValue, valueIndex))];
        CFRelease(multiValue);
    }

    [self composeViewController: picker.mode recipients: recipients completion:^(UIViewController * vc) {
        UIViewController * parent = picker.presentingViewController;
        [parent dismissViewControllerAnimated: YES completion:^{
            [parent presentViewController: vc animated: YES completion: nil];
        }];
    }];
}

- (void) peopleMultiPickerDidCancel:(PeopleMultiPickerViewController *)picker {
    [picker.presentingViewController dismissViewControllerAnimated: YES completion: nil];
}

#pragma - MFMailComposerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {

    switch (result) {
        case MFMailComposeResultCancelled:
        case MFMailComposeResultSaved:
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            [[[UIAlertView alloc] initWithTitle: error.localizedDescription
                                        message: error.localizedFailureReason
                                       delegate: nil
                              cancelButtonTitle: NSLocalizedString(@"ok", nil)
                              otherButtonTitles: nil] show];
            NSLog(@"mailComposeControllerr:didFinishWithResult MFMailComposeResultFailed");
            break;
    }
    [controller.presentingViewController dismissViewControllerAnimated: YES completion: nil];
}


- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {

    switch (result) {
        case MessageComposeResultCancelled:
        case MessageComposeResultSent:
            break;
        case MessageComposeResultFailed:
            NSLog(@"messageComposeViewController:didFinishWithResult MessageComposeResultFailed");
            break;
    }
    [controller.presentingViewController dismissViewControllerAnimated: YES completion: nil];
}

#pragma - MFMessageComposerDelegate

@synthesize addressBook = _addressBook;
- (ABAddressBookRef) addressBook {
    if (_addressBook == nil) {
        CFErrorRef error;
        _addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    }
    return _addressBook;
}

@synthesize invitationCodeViewController = _invitationCodeViewController;
- (InvitationCodeViewController*) invitationCodeViewController {
    if (_invitationCodeViewController == nil) {
        _invitationCodeViewController = [[InvitationCodeViewController alloc] init];
    }
    return _invitationCodeViewController;
}

- (HXOBackend*) chatBackend {
    return ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
}

- (void) dealloc {
    CFRelease(self.addressBook);
    _addressBook = NULL;
}
@end
