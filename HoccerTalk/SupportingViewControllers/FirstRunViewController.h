//
//  FirstRunViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 27.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InsetImageView;

@interface FirstRunViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate>
{
    IBOutlet UITextField * identityTextField;
    IBOutlet InsetImageView * avatarView;
  	NSArray * identities;
    NSArray * avatars;
    UIPickerView * identityPicker;

    IBOutlet UITextField* messageCountTextField;
    NSMutableArray * messageCounts;
    UIPickerView * messageCountPicker;
}

- (IBAction) donePressed: (id) sender;

@end
