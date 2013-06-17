//
//  Contact.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Contact.h"
#import "Crypto.h"
#import "NSData+Base64.h"
#import "RSA.h"
#import "HXOUserDefaults.h"
#import "HXOBackend.h" // for date conversion


// const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic type;
@dynamic avatar;
@dynamic avatarURL;
@dynamic avatarUploadURL;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic status;

// @dynamic currentTimeSection;
@dynamic unreadMessages;
@dynamic latestMessage;
@dynamic publicKey;
@dynamic publicKeyId;
@dynamic connectionStatus;
@dynamic presenceLastUpdated;

@dynamic phoneNumber;
@dynamic mailAddress;
@dynamic twitterName;
@dynamic facebookName;
@dynamic googlePlusName;
@dynamic githubName;

@dynamic messages;
@dynamic groupMemberships;
@dynamic nickNameWithStatus;
@dynamic myGroupMembership;

@synthesize rememberedLastVisibleChatCell;

NSString * const kRelationStateNone    = @"none";
NSString * const kRelationStateFriend  = @"friend";
NSString * const kRelationStateBlocked = @"blocked";


@dynamic relationshipState;
@dynamic relationshipLastChanged;
@dynamic relationshipLastChangedMillis;

@dynamic presenceLastUpdatedMillis;

- (NSNumber*) relationshipLastChangedMillis {
    return [HXOBackend millisFromDate:self.relationshipLastChanged];
}

- (void) setRelationshipLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.relationshipLastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSNumber*) presenceLastUpdatedMillis {
    return [HXOBackend millisFromDate:self.presenceLastUpdated];
}

- (void) setPresenceLastUpdatedMillis:(NSNumber*) milliSecondsSince1970 {
    self.presenceLastUpdated = [HXOBackend dateFromMillis:milliSecondsSince1970];
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
    self.avatarUploadURL = nil;
    [self didChangeValueForKey: @"avatar"];
    [self didChangeValueForKey: @"avatarImage"];
}

- (void) setAvatarImage:(UIImage *)avatarImage {
    [self willChangeValueForKey: @"avatar"];
    [self willChangeValueForKey: @"avatarImage"];
    _avatarImage = avatarImage;
    self.avatarUploadURL = nil; // clear Upload URL so we know if we have to upload it in case of group avatars
    [self setPrimitiveValue: UIImageJPEGRepresentation( _avatarImage, 1.0) forKey: @"avatar"];
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


+ (NSString*) sectionTitleForMessageTime: (NSDate*) date {
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return[formatter stringFromDate: date];
}
/*
- (NSDate*) sectionTimeForMessageTime: (NSDate*) date {
    return [NSDate dateWithTimeIntervalSince1970:100];
    
    if ((self.latestMessageTime == nil) ||
        [date timeIntervalSinceDate: self.latestMessageTime] > kTimeSectionInterval ||
        self.currentTimeSection == nil)
    {
        self.currentTimeSection = date;
    } else {
        if ([date timeIntervalSinceDate:self.currentTimeSection] < 0) {
            // date is before self.currentTimeSection
            return date; // TODO: this will introduce a new time section, the proper way would be to search all existing time sections and choose the right one; however, timeAccepted and timeSection must yield the same sort order, otherwise we will crash
        }
    }
    return self.currentTimeSection;
}
*/

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
            // NSLog(@"Contact:getPublicKeyRef: changed public key of %@", self.nickName);
        }
    }
    myResult = [rsa getPeerKeyRef:self.clientId];
    if (myResult == nil) {
        NSLog(@"ERROR: Contact:getPublicKeyRef: failed for client id %@, nick %@", self.clientId, self.nickName);
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
