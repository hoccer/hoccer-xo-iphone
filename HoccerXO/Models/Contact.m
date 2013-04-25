//
//  Contact.m
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Contact.h"
#import "Crypto.h"
#import "NSData+Base64.h"
#import "RSA.h"
#import "HXOUserDefaults.h"


const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic avatar;
@dynamic avatarURL;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic status;

@dynamic currentTimeSection;
@dynamic unreadMessages;
@dynamic latestMessage;
@dynamic publicKey;
@dynamic publicKeyId;
@dynamic connectionStatus;

@dynamic phoneNumber;
@dynamic mailAddress;
@dynamic twitterName;
@dynamic facebookName;
@dynamic googlePlusName;
@dynamic githubName;

@dynamic messages;
@dynamic nickNameWithStatus;

NSString * const kRelationStateNone    = @"none";
NSString * const kRelationStateFriend  = @"friend";
NSString * const kRelationStateBlocked = @"blocked";


@dynamic relationshipState;
@dynamic relationshipLastChanged;
@dynamic relationshipLastChangedMillis;

- (void) setRelationshipLastChanged:(id) time {
    if ([time isKindOfClass:[NSNumber class]]) {
        time = [NSDate dateWithTimeIntervalSince1970: [time doubleValue] / 1000.0];
    }
    [self willChangeValueForKey: @"relationshipLastChanged"];
    [self setPrimitiveValue: time forKey: @"relationshipLastChanged"];
    [self didChangeValueForKey: @"relationshipLastChanged"];
}

- (NSNumber*) relationshipLastChangedMillis {
    if (self.relationshipLastChanged == nil) {
        return [NSNumber numberWithDouble:0];
    }
    return [NSNumber numberWithLongLong:[self.relationshipLastChanged timeIntervalSince1970]*1000];
}

- (void) setRelationshipLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.relationshipLastChanged = [NSDate dateWithTimeIntervalSince1970: [milliSecondsSince1970 doubleValue] / 1000.0];
}


@synthesize avatarImage = _avatarImage;

- (UIImage*) avatarImage {
    if (_avatarImage == nil) {
        _avatarImage = self.avatar == nil ? nil : [UIImage imageWithData: self.avatar];
    }
    return _avatarImage;
}

- (void) setAvatar:(NSData *)avatar {
    [self willChangeValueForKey: @"avatar"];
    [self willChangeValueForKey: @"avatarImage"];
    [self setPrimitiveValue: avatar forKey: @"avatar"];
    _avatarImage = nil;
    [self didChangeValueForKey: @"avatar"];
    [self didChangeValueForKey: @"avatarImage"];
}

@dynamic publicKeyString;

-(NSString*) publicKeyString {
    return [self.publicKey asBase64EncodedString];
}

-(void) setPublicKeyString:(NSString*) theB64String {
    self.publicKey = [NSData dataWithBase64EncodedString:theB64String];
}


- (NSString*) sectionTitleForMessageTime: (NSDate*) date {
    if (self.latestMessageTime == nil) {
        self.latestMessageTime = [NSDate date];
    }
    if ([date timeIntervalSinceDate: self.latestMessageTime] > kTimeSectionInterval || self.currentTimeSection == nil) {
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        self.currentTimeSection = [formatter stringFromDate: date];
    }
    return self.currentTimeSection;
}

- (SecKeyRef) getPublicKeyRef {
    RSA * rsa = [RSA sharedInstance];
    SecKeyRef myResult = [rsa getPeerKeyRef:self.clientId];
    if (myResult == nil) {
        // store public key from contact in key store
        [rsa addPublicKey: self.publicKeyString withTag: self.clientId];
    } else {
        // check if correct key id in key store
        NSData * myKeyBits = [rsa getKeyBitsForPeerRef:self.clientId];
        if (![myKeyBits isEqualToData:self.publicKey]) {
            [rsa removePeerPublicKey:self.clientId];
            [rsa addPublicKey: self.publicKeyString withTag: self.clientId];
            NSLog(@"Contact:getPublicKeyRef: changed public key of %@", self.nickName);
        }
    }
    myResult = [rsa getPeerKeyRef:self.clientId];
    if (myResult == nil) {
        NSLog(@"ERROR: Contact:getPublicKeyRef: failed.");
    }
    return myResult;
}

- (NSString*) nickNameWithStatus {
    if (self.connectionStatus == nil) {
        return self.nickName;
    } else if ([self.connectionStatus isEqualToString:@"online"]) {
        return [NSString stringWithFormat:@"%@ ⇄", self.nickName];
    } else if ([self.connectionStatus isEqualToString:@"offline"]) {
        return self.nickName;
    } else {
        return [NSString stringWithFormat:@"%@ [%@]", self.nickName, self.connectionStatus];
    }
}



- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"relationshipState",
              @"lastChanged": @"relationshipLastChangedMillis",
              };
}

- (id) valueForUndefinedKey:(NSString *)key {
    if ([key isEqualToString: @"password"]) {
        return nil;
    }
    return [super valueForUndefinedKey: key];
}

@end
