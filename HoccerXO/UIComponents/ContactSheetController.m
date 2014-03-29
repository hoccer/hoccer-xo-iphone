//
//  ContactSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetController.h"

@interface ContactSheetController ()

@property (nonatomic, strong) DatasheetItem * keyItem;
@property (nonatomic, strong) UIView * avatarView;

@end

@implementation ContactSheetController

- (void) commonInit {
    [super commonInit];
    
    self.isEditable = YES;
    
    DatasheetItem * nickNameItem = [self itemWithIdentifier: @"Name" cellIdentifier: @"DatasheetTextInputCell"];
    nickNameItem.valuePath = @"nickname";
    nickNameItem.placeholder = NSLocalizedString(@"Your Name", nil);
    nickNameItem.enabledMask = DatasheetModeEdit;
    nickNameItem.validator = ^BOOL(DatasheetItem* item) {
        return item.currentValue && ! [item.currentValue isEqualToString: @""];
    };

    self.keyItem = [self itemWithIdentifier: @"Key" cellIdentifier: @"DatasheetKeyValueCell"];

    DatasheetSection * commonSection = [DatasheetSection datasheetSectionWithIdentifier: @"common_section"];
    commonSection.footerText = [[NSAttributedString alloc] initWithString: @"Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet."];
    commonSection.items = @[nickNameItem, self.keyItem];

    DatasheetItem * bingo = [self itemWithIdentifier: @"Bingo" cellIdentifier: @"DatasheetActionCell"];
    bingo.visibilityMask = DatasheetModeEdit;
    DatasheetItem * bongo = [self itemWithIdentifier: @"Bongo" cellIdentifier: @"DatasheetActionCell"];
    bongo.visibilityMask = DatasheetModeEdit;
    DatasheetSection * bingoBongoSection = [DatasheetSection datasheetSectionWithIdentifier: @"bingo_bongo_section"];
    bingoBongoSection.items = @[bingo, bongo];

    DatasheetItem * magicButton = [self itemWithIdentifier: @"Magic" cellIdentifier: @"DatasheetActionCell"];
    magicButton.visibilityMask = DatasheetModeEdit;
    DatasheetItem * destructiveButton = [self itemWithIdentifier: @"Delete" cellIdentifier: @"DatasheetActionCell"];

    DatasheetSection * destructiveSection = [DatasheetSection datasheetSectionWithIdentifier: @"destructive_section"];
    destructiveSection.items = @[magicButton, destructiveButton];

    self.items = @[commonSection, bingoBongoSection, destructiveSection];
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: _keyItem]) {
        return @"Verified";
    }
    return [super valueForItem: item];
}

- (void) didUpdateInspectedObject {
    NSLog(@"name: %@", [self.inspectedObject valueForKeyPath: @"nickname"]);
}

- (UIView*) tableHeaderView {
    if ( ! self.avatarView) {
        self.avatarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
        //self.avatarView.backgroundColor = [UIColor orangeColor];
    }
    return self.avatarView;
}

@end
