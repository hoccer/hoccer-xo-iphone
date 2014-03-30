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

#import "AvatarContact.h"

#import "UIImage+ImageEffects.h"

@interface ContactSheetController ()

@property (nonatomic, strong) DatasheetItem * keyItem;
@property (nonatomic, readonly) ProfileAvatarView * avatarView;

@end

@implementation ContactSheetController

@synthesize avatarView = _avatarView;

- (void) commonInit {
    [super commonInit];
    DatasheetItem * nickNameItem = [self itemWithIdentifier: @"Name" cellIdentifier: @"DatasheetTextInputCell"];
    nickNameItem.valuePath = kHXONickName;
    nickNameItem.placeholder = NSLocalizedString(@"Your Name", nil);
    nickNameItem.enabledMask = DatasheetModeEdit;
    nickNameItem.validator = ^BOOL(DatasheetItem* item) {
        return item.currentValue && ! [item.currentValue isEqualToString: @""];
    };

    self.keyItem = [self itemWithIdentifier: @"Key" cellIdentifier: @"DatasheetKeyValueCell"];

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
    NSLog(@"name: %@", [self.inspectedObject valueForKeyPath: kHXONickName]);
}

- (ProfileAvatarView*) avatarView {
    if (! _avatarView) {
        _avatarView = [[ProfileAvatarView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
        _avatarView.defaultIcon = [[AvatarContact alloc] init];
    }
    return _avatarView;
}

- (UIView*) tableHeaderView {
    return self.avatarView;
}

- (UIImage*) updateBackgroundImage {
    UIImage * image = [UIImage imageNamed:@"Default"];
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], CGRectMake(0, 0, 2 * 320, 2 * 160));
    image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    UIColor *tintColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    //UIColor *tintColor = [UIColor colorWithWhite:0.0 alpha:0.1];

    return [image applyBlurWithRadius: 5.0 tintColor: tintColor saturationDeltaFactor: 1.5 maskImage: nil];
}

@end
