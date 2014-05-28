//
//  KeySheetController.m
//  HoccerXO
//
//  Created by David Siegel on 31.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "KeySheetController.h"

#import "HXOBackend.h"
#import "Contact.h"
#import "CCRSA.h"
#import "HXOUI.h"
#import "UserProfile.h"
#import "ModalTaskHUD.h"
#import "AppDelegate.h"

@interface KeySheetController ()

@property (nonatomic, readonly) DatasheetSection * fingerprintSection;
@property (nonatomic, readonly) DatasheetItem * fingerprintItem;
@property (nonatomic, readonly) DatasheetItem * keyLengthItem;
@property (nonatomic, readonly) DatasheetItem * verificationItem;

@property (nonatomic, readonly) DatasheetSection * renewKeypairSection;
@property (nonatomic, readonly) DatasheetItem * renewKeypairItem;
@property (nonatomic, readonly) DatasheetItem * exportKeypairItem;

@property (nonatomic, readonly) id<HXOClientProtocol> client;
@property (nonatomic, readonly) Contact * contact;
@property (nonatomic, readonly) UserProfile * userProfile;

@property (nonatomic, readonly) DatasheetSection * destructiveSection;
@property (nonatomic, readonly) DatasheetItem * destructiveItem;

@end

@implementation KeySheetController

@synthesize fingerprintSection = _fingerprintSection;
@synthesize fingerprintItem = _fingerprintItem;
@synthesize keyLengthItem = _keyLengthItem;
@synthesize verificationItem = _verificationItem;
@synthesize renewKeypairItem = _renewKeypairItem;
@synthesize renewKeypairSection = _renewKeypairSection;
@synthesize exportKeypairItem = _exportKeypairItem;
@synthesize destructiveSection = _destructiveSection;
@synthesize destructiveItem = _destructiveItem;


- (void) commonInit {
    [super commonInit];
    self.isCancelable = NO;
}

- (id<HXOClientProtocol>) client {
    if ([self.inspectedObject conformsToProtocol: @protocol(HXOClientProtocol)]) {
        return self.inspectedObject;
    }
    return nil;
}

- (Contact*) contact {
    if ([self.inspectedObject isKindOfClass:[Contact class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (UserProfile*) userProfile {
    if ([self.inspectedObject isKindOfClass:[UserProfile class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (BOOL) isEditable {
    return [self.inspectedObject isKindOfClass: [UserProfile class]];
}

- (NSString*) title {
    return NSLocalizedString(self.userProfile ? @"key_yours_nav_title" : @"key_others_nav_title", nil);
}

- (DatasheetSection*) fingerprintSection {
    if ( ! _fingerprintSection) {
        _fingerprintSection = [DatasheetSection datasheetSectionWithIdentifier: @"fingerprint_section"];
        _fingerprintSection.items = @[self.fingerprintItem, self.keyLengthItem];
        _fingerprintSection.footerText = HXOLocalizedStringWithLinks(@"key_fingerprint_info", nil);
    }
    return _fingerprintSection;
}

- (DatasheetItem*) fingerprintItem {
    if ( ! _fingerprintItem) {
        _fingerprintItem = [self itemWithIdentifier: @"key_fingerprint_title" cellIdentifier: @"DatasheetKeyValueCell"];
        _fingerprintItem.dependencyPaths = @[@"publicKeyId"];
    }
    return _fingerprintItem;
}

- (DatasheetItem*) keyLengthItem {
    if ( ! _keyLengthItem) {
        _keyLengthItem = [self itemWithIdentifier: @"key_length_item" cellIdentifier: @"DatasheetKeyValueCell"];
        _keyLengthItem.valueFormatString = @"key_length_unit_format";
        _keyLengthItem.valuePath = @"keyLength";
        _fingerprintItem.dependencyPaths = @[@"publicKeyId"];
    }
    return _keyLengthItem;
}

- (NSArray*) buildSections {
    return @[self.fingerprintSection, self.renewKeypairSection, self.destructiveSection];
}

- (void) inspectedObjectDidChange {
    NSArray * common = @[self.fingerprintItem, self.keyLengthItem];
    [self removeObjectObservers];
    self.fingerprintSection.items = self.contact ? [common arrayByAddingObject: self.verificationItem] : common;
    [self addObjectObservers];
    [super inspectedObjectDidChange];
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.fingerprintItem]) {
        return [self fingerprint];
    }/* else if ([item isEqual: self.keyLengthItem]) {
        return [self keyLength];
    }*/
    return [super valueForItem: item];
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.verificationItem]) {
        return self.contact && [super isItemVisible: item];
    }
    return [super isItemVisible: item];
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.verificationItem]) {
        return [self verificationItemTitle];
    }
    return nil;
}

#pragma mark - Key Attributes

- (NSNumber*) keyLength {
    return self.client.keyLength;
}

- (NSString*) fingerprint {
    return [HXOUI formatKeyFingerprint: self.client.publicKeyId];
}

#pragma mark - Key Verification

- (DatasheetItem*) verificationItem {
    if ( ! _verificationItem) {
        _verificationItem = [self itemWithIdentifier: @"key_verification_item" cellIdentifier: @"DatasheetActionCell"];
        _verificationItem.target = self;
        _verificationItem.action = @selector(verificationToggled:);
        _verificationItem.dependencyPaths = @[@"verifiedKey"];
    }
    return _verificationItem;
}

- (BOOL) keyIsVerified {
    return self.contact.verifiedKey && [self.contact.verifiedKey isEqualToData: self.contact.publicKey];
}

- (NSString*) verificationItemTitle {
    if ([self keyIsVerified]) {
        return NSLocalizedString((@"key_unverify_public_btn_title"), nil);
    } else {
        return  NSLocalizedString((@"key_verify_public_btn_title"), nil);
    }
}

- (void) verificationToggled: (id) sender {
    if ([self keyIsVerified]) {
        self.contact.verifiedKey = nil;
    } else {
        self.contact.verifiedKey = self.contact.publicKey;
    }
}

#pragma mark - RSA Keypair Renewal

- (DatasheetSection*) renewKeypairSection {
    if ( ! _renewKeypairSection) {
        _renewKeypairSection = [DatasheetSection datasheetSectionWithIdentifier: @"renew_keypair_section"];
        _renewKeypairSection.items = @[self.renewKeypairItem, self.exportKeypairItem];
        _renewKeypairSection.footerText = HXOLocalizedStringWithLinks(@"key_renew_keypair_info", nil);
    }
    return _renewKeypairSection;
}

- (DatasheetItem*) renewKeypairItem {
    if (! _renewKeypairItem) {
        _renewKeypairItem = [self itemWithIdentifier: @"" cellIdentifier: @"DatasheetActionCell"];
        _renewKeypairItem.title = @"key_renew_keypair";
        _renewKeypairItem.visibilityMask = DatasheetModeEdit;
        _renewKeypairItem.target = self;
        _renewKeypairItem.action = @selector(renewKeypairPressed:);
    }
    return _renewKeypairItem;
}

- (DatasheetItem*) exportKeypairItem {
    if (! _exportKeypairItem) {
        _exportKeypairItem = [self itemWithIdentifier: @"" cellIdentifier: @"DatasheetActionCell"];
        _exportKeypairItem.title = @"key_export_keypair";
        _exportKeypairItem.visibilityMask = DatasheetModeEdit;
        _exportKeypairItem.target = self;
        _exportKeypairItem.action = @selector(exportKeypairPressed:);
    }
    return _exportKeypairItem;
}

- (void) renewKeypairPressed: (id) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == 0) {
            [AppDelegate renewRSAKeyPairWithSize: kHXODefaultKeySize];
        } else if (buttonIndex == 1) {
            [self.delegate performSegueWithIdentifier: @"createCustomKey" sender: sender];
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"key_renew_option_sheet_title", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: NSLocalizedString(@"key_renew_option_automatic", nil),
                                                         NSLocalizedString(@"key_renew_option_manual", nil),
                                                         nil];
    [sheet showInView: self.delegate.view];
}

- (void) exportKeypairPressed: (id) sender {
    void(^export)(BOOL,BOOL) = ^(BOOL public, BOOL private) {
        NSString * keyString = [NSString stringWithFormat: @"%@ %@ %@ (RSA)\n", [self keyLength], [self fingerprint], self.client.nickName];

        if (public) {
            keyString = [keyString stringByAppendingString: [CCRSA makeX509FormattedPublicKey: self.client.publicKey]];
        }
        if (private) {
            keyString = [keyString stringByAppendingString: [CCRSA makePEMFormattedPrivateKey: [[CCRSA sharedInstance] getPrivateKeyBits]]];
        }

        [[UIPasteboard generalPasteboard] setString: keyString];
        [HXOUI showErrorAlertWithMessage:@"key_export_success" withTitle:@"key_export_success_title"];
    };

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * sheet) {
        if (buttonIndex != sheet.cancelButtonIndex) {
            BOOL exportPublic = buttonIndex == 0 || buttonIndex == 2;
            BOOL exportPrivate = buttonIndex == 1 || buttonIndex == 2;
            if (exportPrivate) {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: nil
                                                                 message: NSLocalizedString(@"key_export_private_safety_question", nil)
                                                         completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                             if (buttonIndex != alertView.cancelButtonIndex) {
                                                                 export(exportPublic, exportPrivate);
                                                             }
                                                         }
                                                       cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                                       otherButtonTitles: NSLocalizedString(@"key_export_confirm_btn_title", nil), nil];
                [alert show];
            } else {
                export(exportPublic, exportPrivate);
            }
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"key_export_option_sheet_title", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: NSLocalizedString(@"key_export_option_public", nil), NSLocalizedString(@"key_export_option_private", nil), NSLocalizedString(@"key_export_option_both", nil), nil];

    [sheet showInView: self.delegate.view];
}

#pragma mark - Destructive Section

- (DatasheetSection*) destructiveSection {
    if ( ! _destructiveSection) {
        _destructiveSection = [DatasheetSection datasheetSectionWithIdentifier: @"destructive_section"];
        _destructiveSection.items = @[self.destructiveItem];
    }
    return _destructiveSection;
}

- (DatasheetItem*) destructiveItem {
    if ( ! _destructiveItem) {
        _destructiveItem = [self itemWithIdentifier: @"key_delete_all" cellIdentifier: @"DatasheetActionCell"];
        _destructiveItem.visibilityMask = DatasheetModeEdit;
        _destructiveItem.titleTextColor = [HXOUI theme].destructiveTextColor;
        _destructiveItem.target = self;
        _destructiveItem.action = @selector(deleteAllKeys:);
    }
    return _destructiveItem;
}

- (void) deleteAllKeys: (id) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger button, UIActionSheet * sheet) {
        if (button != sheet.cancelButtonIndex) {
            [self.userProfile deleteAllKeys];
            [AppDelegate renewRSAKeyPairWithSize: kHXODefaultKeySize];
        }
    };
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"key_delete_all_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

@end
