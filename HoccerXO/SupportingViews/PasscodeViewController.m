//
//  PasscodeViewController.m
//  HoccerXO
//
//  Created by David Siegel on 16.03.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "PasscodeViewController.h"
#import "HXOUserDefaults.h"
#import "AppDelegate.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "UIAlertView+BlockExtensions.h"

@interface PasscodeViewController ()

@property (nonatomic, weak) IBOutlet UITextField * passcodeField;
@property (nonatomic, weak) IBOutlet UIImageView * iconView;
@property (nonatomic, weak) IBOutlet UILabel     * prompt;

@end

@implementation PasscodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.prompt.text = NSLocalizedString(@"access_control_prompt", nil);
    self.passcodeField.secureTextEntry = YES;
    self.passcodeField.textAlignment = NSTextAlignmentCenter;
    self.passcodeField.returnKeyType = UIReturnKeyDone;
    self.passcodeField.delegate = self;
    self.iconView.image = [(AppDelegate*)[UIApplication sharedApplication].delegate appIcon];
    self.iconView.contentMode = UIViewContentModeScaleAspectFit;
    self.iconView.layer.cornerRadius = 16.0;
    self.iconView.layer.masksToBounds = YES;

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.iconView attribute: NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    NSDictionary * views = @{@"icon": self.iconView, @"prompt": self.prompt, @"field": self.passcodeField};

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-[prompt]-|" options:0 metrics: nil views: views]];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-(64)-[field]-(64)-|" options:0 metrics: nil views: views]];

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|-64-[icon]-(40)-[prompt]-(16)-[field]-(>=10)-|" options:0 metrics: nil views: views]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    BOOL isSimple = NO;
    self.passcodeField.keyboardType = isSimple ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
    self.passcodeField.text = @"";
    [self.passcodeField becomeFirstResponder];
    [self presentTouchIdIfEnabled];
}

- (void) presentTouchIdIfEnabled {
    if ([PasscodeViewController touchIdEnabled]) {
        [self authenticateUsingTouchId];
    }
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    if ([self.passcodeField isEqual: textField]) {
        BOOL success = [self.passcodeField.text isEqualToString: [PasscodeViewController passcode]];
        self.passcodeField.text = @"";
        if (success) {
            if (self.completionBlock) {
                self.completionBlock();
            }
            [self.presentingViewController dismissViewControllerAnimated: YES completion: nil];
        } else {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"access_control_wrong_passcode_title", nil)
                                                             message:nil
                                                     completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                         [self presentTouchIdIfEnabled];

                                                     }
                                                   cancelButtonTitle: @"Ok"
                                                   otherButtonTitles: nil];
            [alert show];
        }

    }
    return YES;
}

- (void) authenticateUsingTouchId {
    LAContext *context = [[LAContext alloc] init];

    NSError *error = nil;
    if ([context canEvaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [context evaluatePolicy: LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason: NSLocalizedString(@"access_control_touch_id_reason", nil)
                          reply:^(BOOL success, NSError *error) {
                              UIAlertView * alert;
                              void(^block)() = nil;
                              if (error) {

                                  if (error.code == LAErrorUserFallback) {
                                      //block = ^{ [self showPasscodeDialog]; };
                                  } else if (error.code == LAErrorUserCancel) {
                                      block = ^{ [self presentTouchIdIfEnabled]; };
                                  } else {
                                      alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"error", nil)
                                                                         message: error.userInfo[NSLocalizedDescriptionKey]
                                                                 completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                                     [self presentTouchIdIfEnabled];
                                                                 }
                                                               cancelButtonTitle:@"Ok"
                                                               otherButtonTitles:nil];
                                  }
                                  if (block) {
                                      dispatch_async(dispatch_get_main_queue(), block);
                                  }
                              } else if (success) {
                                  // all good
                                  if (self.completionBlock) {
                                      self.completionBlock();
                                  }
                                  [self.presentingViewController dismissViewControllerAnimated: YES completion: nil];
                              } else {
                                  alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                     message:@"You are not the device owner."
                                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                                 [self presentTouchIdIfEnabled];
                                                             }
                                                           cancelButtonTitle:@"Ok"
                                                           otherButtonTitles:nil];
                              }
                              if (alert) {
                                  dispatch_async(dispatch_get_main_queue(), ^{ [alert show]; });
                              }
                          }];

    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"error", nil)
                                                        message: NSLocalizedString(@"access_control_touch_id_impossible", nil)
                                                       delegate: nil
                                              cancelButtonTitle: @"Ok"
                                              otherButtonTitles: nil];
        [alert show];

    }
}

+ (BOOL) passcodeEnabled {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTimeout] && [[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTimeout] isKindOfClass: [NSNumber class]];
}

+ (NSString*) passcode {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlPassscode];
}

+ (double) passcodeTimeout {
    return [[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTimeout] doubleValue];
}

+ (BOOL) touchIdEnabled {
    return [[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTouchIdEnabled] boolValue];
}
@end
