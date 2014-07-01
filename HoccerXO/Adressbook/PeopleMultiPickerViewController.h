//
//  HXOPeoplePickerViewController.h
//  HoccerXO
//
//  Created by David Siegel on 07.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AddressBookUI/AddressBookUI.h>

typedef enum PeoplePickerModes {
    PeoplePickerModeMail,
    PeoplePickerModeText
} PeoplePickerMode;

@interface PeopleMultiPickerViewController : UITableViewController <ABPersonViewControllerDelegate>

@property (nonatomic,assign) PeoplePickerMode mode;

@end
