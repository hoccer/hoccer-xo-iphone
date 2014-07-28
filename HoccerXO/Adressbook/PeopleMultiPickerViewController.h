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

@class PeopleMultiPickerViewController;

@protocol PeopleMultiPickerDelegate <NSObject>

- (void) peopleMultiPicker: (PeopleMultiPickerViewController*) picker didFinishWithSelection: (NSArray*) people;
- (void) peopleMultiPickerDidCancel:(PeopleMultiPickerViewController *)picker;

@end

@interface PeopleMultiPickerViewController : UITableViewController <ABPersonViewControllerDelegate, UISearchBarDelegate>

@property (nonatomic,assign) PeoplePickerMode              mode;
@property (nonatomic,weak)   id<PeopleMultiPickerDelegate> delegate;

@end
