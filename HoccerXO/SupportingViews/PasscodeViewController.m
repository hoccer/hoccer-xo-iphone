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

@interface PasscodeViewController ()

@property (nonatomic, weak) IBOutlet UITextField * passcodeField;
@property (nonatomic, weak) IBOutlet UIImageView * iconView;

@end

@implementation PasscodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.passcodeField.secureTextEntry = YES;
    self.passcodeField.delegate = self;
    self.iconView.image = [(AppDelegate*)[UIApplication sharedApplication].delegate appIcon];
    self.iconView.contentMode = UIViewContentModeCenter;

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
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    if ([self.passcodeField isEqual: textField]) {
        if (self.completionBlock) {
            self.completionBlock(self.passcodeField.text);
        }
        self.passcodeField.text = @"";
        [self.presentingViewController dismissViewControllerAnimated: YES completion: nil];
    }
    return YES;
}

+ (BOOL) passcodeEnabled {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTimeout] && [[[HXOUserDefaults standardUserDefaults] valueForKey: kHXOAccessControlTimeout] isKindOfClass: [NSNumber class]];
;
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
