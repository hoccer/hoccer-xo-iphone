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
    self.iconView.image = [(AppDelegate*)[UIApplication sharedApplication].delegate appIcon];
    self.iconView.contentMode = UIViewContentModeCenter;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    BOOL isSimple = [[PasscodeViewController passcodeMode] isEqualToString: @"simple"];
    self.passcodeField.keyboardType = isSimple ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
    [self.passcodeField becomeFirstResponder];
}

+ (NSString*) passcodeMode {
    return [[HXOUserDefaults standardUserDefaults] valueForKey: kHXOPasscodeMode];
}
@end
