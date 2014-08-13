//
//  ContactSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetBase.h"

#import "HXOUserDefaults.h"
#import "AvatarView.h"
#import "DatasheetViewController.h"
#import "avatar_contact.h"
#import "avatar_group.h"
#import "HXOUI.h"
#import "ImageViewController.h"
#import "UIImage+ScaleAndCrop.h"
#import "UIImage+ImageEffects.h"
#import "ContactListViewController.h"
#import "ContactCell.h"

#define DEBUG_PERF NO

static const NSUInteger kHXOMaxNameLength = 25;

@interface ContactSheetBase ()

@property (nonatomic, assign)   BOOL avatarModified;

@end

@implementation ContactSheetBase

@synthesize avatarView = _avatarView;
@synthesize commonSection = _commonSection;
@synthesize nicknameItem = _nicknameItem;
@synthesize relationshipItem = _relationshipItem;
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
    self.avatarItem.segueIdentifier = @"showAvatar";
}

- (UIViewController*)unwindToRootController {
    return self.delegate;
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
        _keyItem.title = @"profile_key_btn_title";
        _keyItem.segueIdentifier = @"showKey";
        _keyItem.accessoryStyle = DatasheetAccessoryDisclosure;
    }
    return _keyItem;
}

- (DatasheetItem*) nicknameItem {
    if ( !_nicknameItem) {
    _nicknameItem = [self itemWithIdentifier: NSLocalizedString(@"profile_name_label", nil) cellIdentifier: @"DatasheetTextInputCell"];
    _nicknameItem.valuePath = kHXONickName;
    _nicknameItem.valuePlaceholder = NSLocalizedString(@"profile_name_placeholder", nil);
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

- (DatasheetItem*) relationshipItem {
    if ( !_relationshipItem) {
        NSString * status = [ContactCell statusStringForContact: (Contact*)self.inspectedObject];
        _relationshipItem = [self itemWithIdentifier: @"status" cellIdentifier: @"DatasheetCell"];
        _relationshipItem.title = status;
    }
    return _relationshipItem;
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
        _destructiveButton = [self itemWithIdentifier: @"delete" cellIdentifier: @"DatasheetActionCell"];
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

- (void) didChangeValueForItem: (DatasheetItem*) item {
    [super didChangeValueForItem: item];
    if ([item isEqual: self.avatarItem]) {
        self.avatarView.image = item.currentValue;
        self.avatarView.isPresent = NO;
        self.avatarView.isBlocked = NO;
        self.avatarView.badgeText = nil;
        [self backgroundImageChanged];
    }
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];
    if (self.avatarModified) {
        // XXX not sure what this is good for ... do we need it?
        self.client.avatarURL = nil;
        self.client.avatarUploadURL = nil;
        self.avatarModified = NO;
    }
}

- (UIView*) tableHeaderView {
    UIView * avatar =  self.avatarView;
    UIView * spacer = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, avatar.bounds.size.height + 2 * kHXOProfileAvatarPadding)];
    spacer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [spacer addSubview: avatar];
    avatar.center = spacer.center;
    return spacer;
}

- (UIImage*) updateBackgroundImage {
    UIImage * image = self.avatarItem.currentValue ? self.avatarItem.currentValue : nil;
    BOOL darken = self.isEditing && [self isItemEnabled: self.avatarItem];
    UIColor * tintColor = [UIColor colorWithWhite: 0.0 alpha: darken ? 0.5 : 0.0];
    if (image) {
        if (image.size.width * image.size.height > 100 * 100) {
            if (DEBUG_PERF) NSLog(@"before resizing: %f x %f", image.size.width, image.size.height);
            NSDate * scaleStart = [NSDate new];
            image = [image imageScaledToSize:CGSizeMake(100.0, image.size.height/image.size.width * 100.0)];
            NSDate * scaleStop = [NSDate new];
            if (DEBUG_PERF) NSLog(@"scaling took %1.3f secs.", [scaleStop timeIntervalSinceDate:scaleStart]);
            if (DEBUG_PERF) NSLog(@"after resizing: %f x %f", image.size.width, image.size.height);
        }
        //return [image applyBlurWithRadius: 3 * kHXOGridSpacing tintColor: tintColor saturationDeltaFactor: 1.8 maskImage: nil];
        NSDate * blurStart = [NSDate new];
        image = [image applyBlurWithRadius: 0.5 * kHXOGridSpacing tintColor: tintColor saturationDeltaFactor: 1.8 maskImage: nil];
        NSDate * blurStop = [NSDate new];
        if (DEBUG_PERF) NSLog(@"blur took %1.3f secs.", [blurStop timeIntervalSinceDate:blurStart]);
        return image;
    } else if (self.isEditing) {
        CGRect r = CGRectMake(0, 0, 1, 1);
        UIGraphicsBeginImageContextWithOptions(r.size, NO, 0);
        [tintColor setFill];
        UIRectFill(r);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    }
    return nil;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    [super prepareForSegue: segue withItem: item sender: sender];
    if ([item isEqual: self.keyItem]) {
        DatasheetController * keyViewController = segue.destinationViewController;
        keyViewController.inspectedObject = self.client;
    } else if ([segue.identifier isEqualToString: @"showAvatar"]) {
        ImageViewController * imageViewController = segue.destinationViewController;
        imageViewController.image = self.avatarItem.currentValue;
    }
}

#pragma mark - Avatar Handling

- (AvatarView*) avatarView {
    if (! _avatarView) {
        _avatarView = [[AvatarView alloc] initWithFrame:CGRectMake(0, 0, kHXOProfileAvatarSize, kHXOProfileAvatarSize)];
        _avatarView.defaultIcon = [[avatar_contact alloc] init];
        _avatarView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [_avatarView addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];
    }
    return _avatarView;
}

- (IBAction)avatarPressed:(id)sender {
    if (self.mode == DatasheetModeEdit && [self isItemEnabled: self.avatarItem]) {
        [self editAvatar];
    } else if (self.avatarItem.currentValue) {
        [(id)self.delegate performSegueWithIdentifier: self.avatarItem.segueIdentifier sender: self];
    }
}

- (void) editAvatar {
    NSMutableArray * buttons = [NSMutableArray array];
    NSMutableArray * handlers = [NSMutableArray array];

    BOOL hasAvatar = _avatarItem.currentValue != nil;

    if (hasAvatar) {
        [handlers addObject: ^(){ [self deleteAvatar]; }];
    }

    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
        [handlers addObject: ^(){ [self pickAvatarFromSource: UIImagePickerControllerSourceTypePhotoLibrary]; }];
        [buttons addObject: NSLocalizedString(@"attachment_src_photo_album_btn_title",nil)];
    }

    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        [handlers addObject: ^(){ [self pickAvatarFromSource: UIImagePickerControllerSourceTypeCamera]; }];
        [buttons addObject: NSLocalizedString(@"attachment_src_camera_btn_title",nil)];
    }

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * sheet) {
        ((void(^)())handlers[buttonIndex])();
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"profile_avatar_option_sheet_title", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: hasAvatar ? NSLocalizedString(@"profile_avatar_option_delete_btn_title", nil) : nil
                                      otherButtonTitleArray: buttons];
    [sheet showInView: self.delegate.view];
}

- (void) deleteAvatar {
    self.avatarItem.currentValue = nil;
    [self didChangeValueForItem: self.avatarItem];
    self.avatarModified = YES;
}

- (void) pickAvatarFromSource: (UIImagePickerControllerSourceType) source {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.sourceType = source;
    picker.allowsEditing = YES;
    picker.delegate = self;
    [self.delegate presentViewController: picker animated: YES completion: nil];
}

- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    if (info != nil) {
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
            UIImageWriteToSavedPhotosAlbum(info[UIImagePickerControllerOriginalImage], nil, nil, nil);
        }

        UIImage * image = info[UIImagePickerControllerEditedImage];

        // TODO: proper size handling
        CGFloat scale;
        if (image.size.height > image.size.width) {
            scale = 128.0 / image.size.width;
        } else {
            scale = 128.0 / image.size.height;
        }
        CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
        UIImage * scaledAvatar = [image imageScaledToSize: size];

        self.avatarItem.currentValue = scaledAvatar;
        [self didChangeValueForItem: self.avatarItem];
        self.avatarModified = YES;
    }
    [self.delegate dismissViewControllerAnimated: YES completion: nil];
}

@end
