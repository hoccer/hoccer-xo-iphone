//
//  InviteCodeViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InviteCodeViewController.h"
#import "AppDelegate.h"
#import "HXOBackend.h"

@implementation InviteCodeViewController

@dynamic navigationItem;

@synthesize chatBackend = _chatBackend;

- (void) viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self
                                                                                action:@selector(canceld:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(onDone:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    self.codeTextField.delegate = self;
    self.codeTextField.autocorrectionType = UITextAutocorrectionTypeNo;

     UIImage * background = [[UIImage imageNamed: @"navbar-btn-blue"] stretchableImageWithLeftCapWidth: 4 topCapHeight: 0];
    [self.getNewCodeButton setBackgroundImage: background forState: UIControlStateNormal];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.label.text = NSLocalizedString(@"or", @"Invite Token View Controller");
    _newTokenButtonPressed = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
    [self onDone: nil];
}

- (IBAction) newCodePressed:(id)sender {
    _newTokenButtonPressed = YES;
    self.navigationItem.leftBarButtonItem = nil;
    [self.chatBackend generateToken: @"pairing" validFor: kInvitationTokenValidity tokenHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        if (![token isKindOfClass:[NSString class]]) {
            self.codeTextField.text = @"<ERROR>";
            return;
        }
        self.label.text = NSLocalizedString(@"Send this token to a friend:", nil);

        self.codeTextField.text = token;
    }];
}

- (void) onDone:(id) sender {
    if ( ! _newTokenButtonPressed) {
        [self.chatBackend pairByToken: self.codeTextField.text];
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) canceld:(id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void)viewDidUnload {
    [self setCodeTextField:nil];
    [self setLabel:nil];
    [self setNavigationItem:nil];
    [super viewDidUnload];
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}


@end
