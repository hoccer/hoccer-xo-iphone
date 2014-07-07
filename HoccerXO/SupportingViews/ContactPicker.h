//
//  ContactPickerViewController.h
//  HoccerXO
//
//  Created by David Siegel on 10.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

typedef enum ContactPickerStyle {
    ContactPickerStyleSingle,
    ContactPickerStyleMulti
} ContactPickerStyle;

typedef enum ContactPickerTypes {
    ContactPickerTypeContact = (1<<0),
    ContactPickerTypeGroup   = (1<<1)

} ContactPickerType;

typedef void(^ContactPickerCompletion)(id result);

@interface ContactPicker : ContactListViewController

+ (id) contactPickerWithTitle: (NSString*)               title
                        style: (ContactPickerStyle)      style
                    predicate: (NSPredicate*)            predicate
                   completion: (ContactPickerCompletion) completion;

@property (nonatomic, assign) ContactPickerStyle        pickerStyle;
@property (nonatomic, copy)   ContactPickerCompletion   completion;
@property (nonatomic, strong) NSPredicate             * predicate;

@end
