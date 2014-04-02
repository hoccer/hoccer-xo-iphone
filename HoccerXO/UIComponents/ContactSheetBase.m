//
//  ContactSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetBase.h"

#import "HXOUserDefaults.h"
#import "ProfileAvatarView.h"
#import "DatasheetViewController.h"
#import "AvatarContact.h"
#import "GhostBustersSign.h"
#import "UIImage+ImageEffects.h"
#import "HXOUI.h"

static const NSUInteger kHXOMaxNameLength = 25;

@interface ContactSheetBase ()

@end


@implementation ContactSheetBase

@synthesize avatarView = _avatarView;
@synthesize commonSection = _commonSection;
@synthesize nicknameItem = _nicknameItem;
@synthesize keyItem = _keyItem;
@synthesize destructiveSection = _destructiveSection;
@synthesize destructiveButton = _destructiveButton;

- (id<HXOClientProtocol>) client {
    if ([self.inspectedObject conformsToProtocol: @protocol(HXOClientProtocol)]) {
        return self.inspectedObject;
    }
    return nil;
}

- (void) commonInit {
    [super commonInit];
    
    _avatarItem = [self itemWithIdentifier: @"avatar_item" cellIdentifier: nil];
    self.avatarItem.visibilityMask = DatasheetModeNone;
    self.avatarItem.valuePath = @"avatarImage";
}

- (NSArray*) buildSections {
    NSMutableArray * sections = [NSMutableArray array];

    [sections addObject: self.avatarItem];

    DatasheetSection * section = self.commonSection;
    if (section) { [sections addObject: section]; }

    [self addUtilitySections: sections];

    section = self.destructiveSection;
    if (section) { [sections addObject: section]; }

    return sections;
}

- (DatasheetSection*) commonSection {
    if ( ! _commonSection) {
        _commonSection = [DatasheetSection datasheetSectionWithIdentifier: @"common_section"];
        _commonSection.items = @[self.nicknameItem, self.keyItem];
    }
    return _commonSection;
}

- (DatasheetItem*) keyItem {
    if (! _keyItem) {
        _keyItem = [self itemWithIdentifier: @"Key" cellIdentifier: @"DatasheetKeyValueCell"];
        _keyItem.title = @"profile_fingerprint_label";
        _keyItem.segueIdentifier = @"showKey";
        _keyItem.accessoryStyle = DatasheetAccessoryDisclosure;
    }
    return _keyItem;
}

- (DatasheetItem*) nicknameItem {
    if ( !_nicknameItem) {
    _nicknameItem = [self itemWithIdentifier: @"Name" cellIdentifier: @"DatasheetTextInputCell"];
    _nicknameItem.valuePath = kHXONickName;
    _nicknameItem.valuePlaceholder = NSLocalizedString(@"Your Name", nil);
    _nicknameItem.enabledMask = DatasheetModeEdit;
    _nicknameItem.validator = ^BOOL(DatasheetItem* item) {
        return item.currentValue && ! [item.currentValue isEqualToString: @""];
    };
    _nicknameItem.changeValidator = ^BOOL(NSString * old, NSString * new) {
        if (old.length > kHXOMaxNameLength) {
            return new.length < old.length;
        }
        return new.length <= kHXOMaxNameLength;
    };
    }
    return _nicknameItem;
}

- (DatasheetSection*) destructiveSection {
    if ( ! _destructiveSection) {
        _destructiveSection = [DatasheetSection datasheetSectionWithIdentifier: @"destructive_section"];

        _destructiveSection.items = @[self.destructiveButton];
    }
    return _destructiveSection;
}

- (DatasheetItem*) destructiveButton {
    if ( ! _destructiveButton) {
        _destructiveButton = [self itemWithIdentifier: @"Delete" cellIdentifier: @"DatasheetActionCell"];
        _destructiveButton.titleTextColor = [HXOUI theme].destructiveTextColor;
        _destructiveButton.visibilityMask = DatasheetModeNone;
    }
    return _destructiveButton;
}

- (void) addUtilitySections: (NSMutableArray*) sections {
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.keyItem]) {
        return [HXOUI formatKeyFingerprint: self.client.publicKeyId];
    }
    return [super valueForItem: item];
}

- (ProfileAvatarView*) avatarView {
    if (! _avatarView) {
        _avatarView = [[ProfileAvatarView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
        _avatarView.defaultIcon = [[AvatarContact alloc] init];
        _avatarView.blockedSign = [[GhostBustersSign alloc] init];
    }
    return _avatarView;
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
    [super didChangeValueForItem: item];
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
        DatasheetController * keyViewController = segue.destinationViewController;
        keyViewController.inspectedObject = self.client;
    } else {
        NSLog(@"Unhandled segue %@", segue.identifier);
    }

}

@end
