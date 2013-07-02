//
//  InvitationController.m
//  HoccerXO
//
//  Created by David Siegel on 25.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InvitationController.h"
#import "InviteCodeViewController.h"
#import "AppDelegate.h"

@interface InvitationChannel : NSObject
@property (nonatomic,strong) NSString* localizedButtonTitle;
@property (nonatomic, assign) SEL handler;
@end

@interface InvitationController ()

@property (nonatomic, strong) NSMutableArray * invitationChannels;
@property (nonatomic, strong) UIViewController * viewController;
@property (nonatomic, readonly) HXOBackend * chatBackend;


@end

static InvitationController * _sharedInvitationController;

@implementation InvitationController

+ (void) initialize {
    _sharedInvitationController = [[InvitationController alloc] init];
}

+ (id) sharedInvitationController {
    return _sharedInvitationController;
}

- (id) init {
    self = [super init];
    if (self != nil) {
        self.invitationChannels = [[NSMutableArray alloc] initWithCapacity: 3];
        if ([MFMessageComposeViewController canSendText]) {
            InvitationChannel * channel = [[InvitationChannel alloc] init];
            channel.localizedButtonTitle = NSLocalizedString(@"SMS",@"Invite Actionsheet Button Title");
            channel.handler = @selector(inviteBySMS);
            [self.invitationChannels addObject: channel];
        }
        if ([MFMailComposeViewController canSendMail]) {
            InvitationChannel * channel = [[InvitationChannel alloc] init];
            channel.localizedButtonTitle = NSLocalizedString(@"Mail",@"Invite Actionsheet Button Title");
            channel.handler = @selector(inviteByMail);
            [self.invitationChannels addObject: channel];
        }
        InvitationChannel * channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = NSLocalizedString(@"Show Invite Code", @"Invite Actionsheet Button Title");
        channel.handler = @selector(inviteByCode);
        [self.invitationChannels addObject: channel];

        channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = NSLocalizedString(@"Scan or Enter Code", @"Invite Actionsheet Button Title");
        channel.handler = @selector(acceptInviteCode);
        [self.invitationChannels addObject: channel];

        /* action sheet test dummy buttons
        channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = @"Gnurbel";
        channel.handler = @selector(acceptInviteCode);
        [self.invitationChannels addObject: channel];

        channel = [[InvitationChannel alloc] init];
        channel.localizedButtonTitle = @"Fnurbel";
        channel.handler = @selector(acceptInviteCode);
        [self.invitationChannels addObject: channel];
         */

    }
    return self;
}

- (void) presentWithViewController: (UIViewController*) viewController {
    self.viewController = viewController;
    ActionSheet * sheet = [[ActionSheet alloc] initWithTitle: NSLocalizedString(@"Invite by", @"Actionsheet Title")
                                                        delegate: self
                                               cancelButtonTitle: nil
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: nil];

    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    for (InvitationChannel * channel in self.invitationChannels) {
        [sheet addButtonWithTitle: channel.localizedButtonTitle];
    }
    sheet.cancelButtonIndex = [sheet addButtonWithTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")];

    [sheet showInView: viewController.view];
}

-(void)actionSheet:(ActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector: ((InvitationChannel*)self.invitationChannels[buttonIndex]).handler];
#pragma clang diagnostic pop
}

- (void) inviteByMail {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;

        [picker setSubject: NSLocalizedString(@"invitation_mail_subject", @"Mail Invitation Subject")];

        NSString * body = NSLocalizedString(@"invitation_mail_body", @"Mail Invitation Body");
        NSString * inviteLink = [self inviteURL: token];
        NSString * appStoreLink = [self appStoreURL];
        NSString * androidLink = [self androidURL];
        body = [NSString stringWithFormat: body, appStoreLink, androidLink, inviteLink];
        [picker setMessageBody:body isHTML:NO];

        [self.viewController presentViewController: picker animated: YES completion: nil];
    }];
}

- (void) inviteBySMS {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
        picker.messageComposeDelegate = self;

        NSString * smsText = NSLocalizedString(@"invitation_sms_text", @"SMS Invitation Body");
        picker.body = [NSString stringWithFormat: smsText, [self inviteURL: token]];

        [self.viewController presentViewController: picker animated: YES completion: nil];

    }];
}

- (void) inviteByCode {
    [self presentInviteByCodeWithPresentMode:YES];
}
- (void) acceptInviteCode {
    [self presentInviteByCodeWithPresentMode:NO];
}


- (void) presentInviteByCodeWithPresentMode:(BOOL)presentCodeMode {
    UIStoryboard * storyboard;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:[NSBundle mainBundle]];
    } else {
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:[NSBundle mainBundle]];
    }
    
    InviteCodeViewController * controller = [storyboard instantiateViewControllerWithIdentifier:@"inviteCodeView"];
    controller.presentCodeMode = presentCodeMode;
    [self.viewController presentViewController: controller animated: YES completion: nil];
    
}

- (NSString*) inviteURL: (NSString*) token {
    return [NSString stringWithFormat: @"hxo://%@", token];
}

- (NSString*) appStoreURL {
    return @"itms-apps://itunes.com/apps/hoccerxo";
}

- (NSString*) androidURL {
    return @"http://google.com";
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {

    // TODO: handle mail result?
	switch (result) {
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
			break;
		default:
			break;
	}
    [self.viewController dismissViewControllerAnimated: NO completion: nil];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {

    // TODO: handle message result?
	switch (result) {
		case MessageComposeResultCancelled:
			break;
		case MessageComposeResultSent:
			break;
		case MessageComposeResultFailed:
			break;
		default:
			break;
	}
    [self.viewController dismissViewControllerAnimated: NO completion: nil];
}

@synthesize chatBackend = _chatBackend;

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

@end

@implementation InvitationChannel
@end

