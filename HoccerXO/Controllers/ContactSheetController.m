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
    DataSheetItem * nickNameItem = [self itemWithTitle: @"Name" cellIdentifier: @"DataSheetTextInputCell"];
    nickNameItem.valuePath = @"nickname";
    nickNameItem.placeholder = NSLocalizedString(@"Your Name", nil);

    self.keyItem = [self itemWithTitle: @"Key" cellIdentifier: @"DataSheetKeyValueCell"];

    DataSheetSection * commonSection = [DataSheetSection dataSheetSection];
    commonSection.items = @[nickNameItem, self.keyItem];

    DataSheetItem * destructiveButton = [self itemWithTitle: @"Delete" cellIdentifier: @"DataSheetActionCell"];

    DataSheetSection * destructiveSection = [DataSheetSection dataSheetSection];
    destructiveSection.items = @[destructiveButton];

    self.items = @[commonSection, destructiveSection];

    //self.inspectedObject = @{@"nickname": @"Dingenshier"};
}

- (id) valueForItem:(DataSheetItem *)item {
    if ([item isEqual: _keyItem]) {
        return @"Verified";
    }
    return [super valueForItem: item];
}

@end
