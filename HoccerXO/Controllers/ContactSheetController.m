//
//  ContactSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetController.h"

@interface ContactSheetController ()

@property (nonatomic,strong) DataSheetItem * keyItem;

@end

@implementation ContactSheetController

- (void) commonInit {
    [super commonInit];
    
    self.isEditable = YES;
    
    DataSheetItem * nickNameItem = [self itemWithIdentifier: @"Name" cellIdentifier: @"DataSheetTextInputCell"];
    nickNameItem.valuePath = @"nickname";
    nickNameItem.placeholder = NSLocalizedString(@"Your Name", nil);
    nickNameItem.enabledMask = DataSheetModeEdit;

    self.keyItem = [self itemWithIdentifier: @"Key" cellIdentifier: @"DataSheetKeyValueCell"];

    DataSheetSection * commonSection = [DataSheetSection dataSheetSection];
    commonSection.items = @[nickNameItem, self.keyItem];

    DataSheetItem * magicButton = [self itemWithIdentifier: @"Magic" cellIdentifier: @"DataSheetActionCell"];
    magicButton.visibilityMask = DataSheetModeEdit;
    DataSheetItem * destructiveButton = [self itemWithIdentifier: @"Delete" cellIdentifier: @"DataSheetActionCell"];

    DataSheetSection * destructiveSection = [DataSheetSection dataSheetSection];
    destructiveSection.items = @[magicButton, destructiveButton];

    self.items = @[commonSection, destructiveSection];
}

- (id) valueForItem:(DataSheetItem *)item {
    if ([item isEqual: _keyItem]) {
        return @"Verified";
    }
    return [super valueForItem: item];
}

@end
