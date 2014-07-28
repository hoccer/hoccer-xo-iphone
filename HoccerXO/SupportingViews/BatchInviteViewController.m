//
//  BatchInviteViewController.m
//  HoccerXO
//
//  Created by David Siegel on 24.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "BatchInviteViewController.h"

#import <AddressBook/AddressBook.h>

#import "AppDelegate.h"
#import "HXOUserDefaults.h"

@interface BatchInviteViewController ()

@property (nonatomic, strong) PeopleMultiPickerViewController * peoplePicker;
@end

@implementation BatchInviteViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.peoplePicker = (PeopleMultiPickerViewController*)self.topViewController;
    self.peoplePicker.delegate = self;
    self.peoplePicker.mode = self.mode;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    UIViewController * vc = nil;
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
        CFErrorRef error;
        ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
            [self setViewControllers: @[[self rootViewForAuthorizationStatus: granted]] animated: YES];
        });
    } else {
        vc = [self rootViewForAuthorizationStatus: ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized];
    }

    [self setViewControllers: vc ? @[vc] : nil];
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController*) rootViewForAuthorizationStatus: (BOOL) granted {
    return granted ? self.peoplePicker : self.mode == PeoplePickerModeMail ?  [[MFMailComposeViewController alloc] init] : [[MFMessageComposeViewController alloc] init];
}

- (void) setMode:(PeoplePickerMode)mode {
    self.peoplePicker.mode = mode;
    _mode = mode;
}

- (void) peopleMultiPicker: (PeopleMultiPickerViewController*) picker didFinishWithSelection: (NSArray*) selection {
    NSMutableArray * recipients = [NSMutableArray array];
    for (NSDictionary * item in selection) {
        ABMultiValueRef multiValue = ABRecordCopyValue((__bridge ABRecordRef)(item[@"person"]), [item[@"property"] integerValue]);
        int valueIndex = ABMultiValueGetIndexForIdentifier(multiValue, [item[@"identifier"] integerValue]);
        [recipients addObject: CFBridgingRelease(ABMultiValueCopyValueAtIndex(multiValue, valueIndex))];
        CFRelease(multiValue);
    }
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        UIViewController * vc;
        if (self.mode == PeoplePickerModeMail) {
            MFMailComposeViewController * mailView = [[MFMailComposeViewController alloc] init];
            vc = mailView;
            mailView.mailComposeDelegate = self;
            [mailView setSubject:  NSLocalizedString(@"invite_mail_subject", nil)];
            [mailView setBccRecipients: recipients];

            NSString * body = NSLocalizedString(@"invite_mail_body", nil);
            body = [NSString stringWithFormat: body, [self appStoreURL], [self inviteURL: token]];
            [mailView setMessageBody: body isHTML: NO];
        } else {
            MFMessageComposeViewController * messageView = [[MFMessageComposeViewController alloc] init];
            vc = messageView;
            messageView.messageComposeDelegate = self;

            NSString * smsText = NSLocalizedString(@"invite_sms_text", nil);
            messageView.body = [NSString stringWithFormat: smsText, [self inviteURL: token], [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName]];

        }
        [self presentViewController: vc animated: YES completion: nil];
    }];
}

- (void) peopleMultiPickerDidCancel:(PeopleMultiPickerViewController *)picker {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) inviteByCode {
    [self performSegueWithIdentifier: @"showInviteCodeViewController" sender: self];
}

- (NSString*) inviteURL: (NSString*) token {
    return [NSString stringWithFormat: @"%@://%@", kHXOURLScheme, token];
}

- (NSString*) appStoreURL {
    return @"itms-apps://itunes.com/apps/hoccerxo";
}

- (NSString*) androidURL {
    return @"http://google.com";
}

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
    // hack... replace with pavels unwind to list view after merging
    [self dismissViewControllerAnimated: YES completion:^{
        [self dismissViewControllerAnimated: YES completion: nil];
    }];
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
    // hack... replace with pavels unwind to list view after merging
    [self dismissViewControllerAnimated: YES completion:^{
        [self dismissViewControllerAnimated: YES completion: nil];
    }];
}

- (HXOBackend*) chatBackend {
    return ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
}

@end
