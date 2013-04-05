//
//  InviteCodeViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 05.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HoccerTalkBackend;

@interface InviteCodeViewController : UIViewController <UITextFieldDelegate>
{
    BOOL _newTokenButtonPressed;
}

@property (nonatomic, readonly) HoccerTalkBackend * chatBackend;
@property (strong, nonatomic) IBOutlet UITextField * codeTextField;
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UIButton *clipboardButton;
@property (strong, nonatomic) IBOutlet UINavigationItem *navigationItem;

@end
