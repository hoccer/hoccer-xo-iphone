//
//  PasscodeViewController.h
//  HoccerXO
//
//  Created by David Siegel on 16.03.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef void(^PasscodeCompletionBlock)(BOOL success);

@interface PasscodeViewController : UIViewController <UITextFieldDelegate>

- (void) presentTouchIdIfEnabled;

+ (NSString*) passcode;
+ (BOOL) passcodeEnabled;
+ (BOOL) touchIdEnabled;
+ (double) passcodeTimeout;

@property (nonatomic,copy) PasscodeCompletionBlock completionBlock;

@end
