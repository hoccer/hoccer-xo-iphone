//
//  ContactSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetController.h"

#import "HXOUserDefaults.h"
#import "ProfileAvatarView.h"
#import "DatasheetViewController.h"

#import "AvatarContact.h"

#import "UIImage+ImageEffects.h"

static const NSUInteger kHXOMaxNameLength = 25;

@interface ContactSheetController ()

@property (nonatomic, strong)   DatasheetItem *     keyItem;
@property (nonatomic, readonly) ProfileAvatarView * avatarView;
@property (nonatomic, readonly) DatasheetItem *     avatarItem;

@end


@implementation ContactSheetController

@synthesize avatarView = _avatarView;

- (void) commonInit {
    [super commonInit];

    self.isEditable = YES;

    _avatarItem = [self itemWithIdentifier: @"avatar_item" cellIdentifier: nil];
    self.avatarItem.visibilityMask = DatasheetModeNone;
    self.avatarItem.valuePath = @"avatarImage";

    DatasheetItem * nickNameItem = [self itemWithIdentifier: @"Name" cellIdentifier: @"DatasheetTextInputCell"];
    nickNameItem.valuePath = kHXONickName;
    nickNameItem.placeholder = NSLocalizedString(@"Your Name", nil);
    nickNameItem.enabledMask = DatasheetModeEdit;
    nickNameItem.validator = ^BOOL(DatasheetItem* item) {
        return item.currentValue && ! [item.currentValue isEqualToString: @""];
    };
    nickNameItem.changeValidator = ^BOOL(NSString * old, NSString * new) {
        if (old.length > kHXOMaxNameLength) {
            return new.length < old.length;
        }
        return new.length <= kHXOMaxNameLength;
    };

    self.keyItem = [self itemWithIdentifier: @"Key" cellIdentifier: @"DatasheetKeyValueCell"];
    self.keyItem.segueIdentifier = @"showKey";

    DatasheetSection * commonSection = [DatasheetSection datasheetSectionWithIdentifier: @"common_section"];
    commonSection.footerText = [[NSAttributedString alloc] initWithString: @"Lorem ipsum dolor sit amet."];
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
    destructiveButton.titleTextColor = [HXOTheme theme].destructiveTextColor;
    destructiveButton.target = self;
    destructiveButton.action = @selector(bongoPressed:);

    DatasheetSection * destructiveSection = [DatasheetSection datasheetSectionWithIdentifier: @"destructive_section"];
    destructiveSection.items = @[magicButton, destructiveButton];

    self.items = @[self.avatarItem, commonSection, bingoBongoSection, destructiveSection];
}

- (void) bongoPressed: (UIViewController*) sender {
    NSLog(@"bongo bongo");
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: _keyItem]) {
        return @"Verified";
    }
    return [super valueForItem: item];
}

- (void) didUpdateInspectedObject {
    NSLog(@"name: %@", [self.inspectedObject valueForKeyPath: kHXONickName]);
}

- (ProfileAvatarView*) avatarView {
    if (! _avatarView) {
        _avatarView = [[ProfileAvatarView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
        _avatarView.defaultIcon = [[AvatarContact alloc] init];
    }
    return _avatarView;
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
    if ([item isEqual: self.avatarItem]) {
        self.avatarView.image = item.currentValue;
        [self backgroundImageChanged];
    }
}

- (UIView*) tableHeaderView {
    return self.avatarView;
}

- (UIImage*) updateBackgroundImage {
    UIColor * tintColor = [UIColor colorWithWhite: 1.0 alpha: 0.0];
    return [self.avatarItem.currentValue applyBlurWithRadius: 20.0 tintColor: tintColor saturationDeltaFactor: 1.5 maskImage: nil];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([item isEqual: self.keyItem]) {
        DatasheetViewController * viewController = segue.destinationViewController;
        viewController.inspectedObject = @{@"size": @1024};
        
    }
}

@end
