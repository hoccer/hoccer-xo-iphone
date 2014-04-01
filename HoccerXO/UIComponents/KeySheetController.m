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

@interface KeySheetController ()

@property (nonatomic, readonly) DatasheetSection * fingerprintSection;
@property (nonatomic, readonly) DatasheetItem * fingerprintItem;
@property (nonatomic, readonly) DatasheetItem * keyLengthItem;
@property (nonatomic, readonly) DatasheetItem * verificationItem;

@end

@implementation KeySheetController

@synthesize fingerprintSection = _fingerprintSection;
@synthesize fingerprintItem = _fingerprintItem;
@synthesize keyLengthItem = _keyLengthItem;
@synthesize verificationItem = _verificationItem;

- (Contact*) contact {
    return self.inspectedObject;
}

- (DatasheetSection*) fingerprintSection {
    if ( ! _fingerprintSection) {
        _fingerprintSection = [DatasheetSection datasheetSectionWithIdentifier: @"fingerprint_section"];
        _fingerprintSection.items = @[self.fingerprintItem, self.keyLengthItem, self.verificationItem];
        _fingerprintSection.footerText = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"profile_fingerprint_info", nil) attributes: nil];
    }
    return _fingerprintSection;
}

- (DatasheetItem*) fingerprintItem {
    if ( ! _fingerprintItem) {
        _fingerprintItem = [self itemWithIdentifier: @"fingerprint_item" cellIdentifier: @"DatasheetKeyValueCell"];
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

- (DatasheetItem*) verificationItem {
    if ( ! _verificationItem) {
        _verificationItem = [self itemWithIdentifier: @"key_verification_item" cellIdentifier: @"DatasheetActionCell"];
        _verificationItem.target = self;
        _verificationItem.action = @selector(verificationToggled:);
        _verificationItem.dependencyPaths = @[@"verifiedKey"];
    }
    return _verificationItem;
}

- (NSArray*) buildSections {
    return @[self.fingerprintSection];
}

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.fingerprintItem]) {
        return [self fingerprint];
    } else if ([item isEqual: self.keyLengthItem]) {
        return @([self keyLength]);
    }
    return [super valueForItem: item];
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.verificationItem]) {
        return [self verificationItemTitle];
    }
    return nil;
}

- (NSString*) fingerprint {
    NSMutableArray * fingerprint = [NSMutableArray array];
    NSString * keyId = self.keyId;
    for (int i = 0; i < keyId.length; i += 2) {
        [fingerprint addObject: [keyId substringWithRange: NSMakeRange(i, 2)]];
    }
    return [fingerprint componentsJoinedByString:@":"];
}

- (NSString*) keyId {
    return self.isOwnKey ? [HXOBackend ownPublicKeyIdString] : self.contact.publicKeyId;
}

- (NSData*) publicKey {
    return self.isOwnKey ? [HXOBackend ownPublicKey] : self.contact.publicKey;
}

- (NSUInteger) keyLength {
    return [CCRSA getPublicKeySize: self.publicKey];
}

- (BOOL) keyIsVerified {
    return self.contact.verifiedKey && [self.contact.verifiedKey isEqualToData:self.contact.publicKey];
}

- (NSString*) verificationItemTitle {
    if ([self keyIsVerified]) {
        return NSLocalizedString((@"unverify_publickey"), nil);
    } else {
        return  NSLocalizedString((@"verify_publickey"), nil);
    }
}

- (void) verificationToggled: (id) sender {
    NSLog(@"verificationToggled");
    if ([self keyIsVerified]) {
        self.contact.verifiedKey = nil;
    } else {
        self.contact.verifiedKey = self.contact.publicKey;
    }
}

@end
