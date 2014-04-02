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
#import "EC.h"
#import "HXOUI.h"
#import "UserProfile.h"

@interface KeySheetController ()

@property (nonatomic, readonly) DatasheetSection * fingerprintSection;
@property (nonatomic, readonly) DatasheetItem * fingerprintItem;
@property (nonatomic, readonly) DatasheetItem * keyLengthItem;
@property (nonatomic, readonly) DatasheetItem * verificationItem;

@property (nonatomic, readonly) DatasheetSection * renewKeypairSection;
@property (nonatomic, readonly) DatasheetItem * renewKeypairItem;

@property (nonatomic, readonly) id<HXOClientProtocol> client;
@property (nonatomic, readonly) Contact * contact;
@property (nonatomic, readonly) UserProfile * userProfile;

@end

@implementation KeySheetController

@synthesize fingerprintSection = _fingerprintSection;
@synthesize fingerprintItem = _fingerprintItem;
@synthesize keyLengthItem = _keyLengthItem;
@synthesize verificationItem = _verificationItem;
@synthesize renewKeypairItem = _renewKeypairItem;
@synthesize renewKeypairSection = _renewKeypairSection;


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

- (DatasheetSection*) fingerprintSection {
    if ( ! _fingerprintSection) {
        _fingerprintSection = [DatasheetSection datasheetSectionWithIdentifier: @"fingerprint_section"];
        _fingerprintSection.items = @[self.fingerprintItem, self.keyLengthItem];
        _fingerprintSection.footerText = HXOLocalizedStringWithLinks(@"profile_fingerprint_info", nil);
    }
    return _fingerprintSection;
}

- (DatasheetItem*) fingerprintItem {
    if ( ! _fingerprintItem) {
        _fingerprintItem = [self itemWithIdentifier: @"fingerprint_item" cellIdentifier: @"DatasheetKeyValueCell"];
        _fingerprintItem.dependencyPaths = @[@"publicKeyId"];
    }
    return _fingerprintItem;
}

- (DatasheetItem*) keyLengthItem {
    if ( ! _keyLengthItem) {
        _keyLengthItem = [self itemWithIdentifier: @"key_length_item" cellIdentifier: @"DatasheetKeyValueCell"];
        _keyLengthItem.valueFormatString = @"key_length_unit";
    }
    return _keyLengthItem;
}

- (NSArray*) buildSections {
    return @[self.fingerprintSection, self.renewKeypairSection];
}

- (void) inspectedObjectChanged {
    NSArray * common = @[self.fingerprintItem, self.keyLengthItem];
    [self removeObjectObservers];
    self.fingerprintSection.items = self.contact ? [common arrayByAddingObject: self.verificationItem] : common;
    [self addObjectObservers];
    [super inspectedObjectChanged];
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.fingerprintItem]) {
        return [self fingerprint];
    } else if ([item isEqual: self.keyLengthItem]) {
        return @([self keyLength]);
    }
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

- (NSUInteger) keyLength {
    return [CCRSA getPublicKeySize: self.client.publicKey];
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
        return NSLocalizedString((@"unverify_publickey"), nil);
    } else {
        return  NSLocalizedString((@"verify_publickey"), nil);
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
        _renewKeypairSection.items = @[self.renewKeypairItem];
        _renewKeypairSection.footerText = HXOLocalizedStringWithLinks(@"profile_renew_keypair_info", nil);
    }
    return _renewKeypairSection;
}

- (DatasheetItem*) renewKeypairItem {
    if (! _renewKeypairItem) {
        _renewKeypairItem = [self itemWithIdentifier: @"" cellIdentifier: @"DatasheetActionCell"];
        _renewKeypairItem.title = @"profile_renew_keypair";
        _renewKeypairItem.visibilityMask = DatasheetModeEdit;
        _renewKeypairItem.target = self;
        _renewKeypairItem.action = @selector(renewKeypairPressed:);
    }
    return _renewKeypairItem;
}

- (void) renewKeypairPressed: (id) sender {
    if ( ! self.renewKeypairItem.isBusy) {
        self.renewKeypairItem.isBusy = YES;
        [self updateItem: self.renewKeypairItem];
        [self.userProfile renewKeypairWithCompletion:^{
            self.renewKeypairItem.isBusy = NO;
            [self updateItem: self.renewKeypairItem];
        }];
    }
}

@end
