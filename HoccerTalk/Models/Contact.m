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


const float kTimeSectionInterval = 2 * 60;

@implementation Contact

@dynamic avatar;
@dynamic avatarURL;
@dynamic clientId;
@dynamic latestMessageTime;
@dynamic nickName;
@dynamic status;
@dynamic relationship;

@dynamic currentTimeSection;
@dynamic unreadMessages;
@dynamic latestMessage;
@dynamic publicKey;
@dynamic publicKeyId;

@dynamic messages;

@synthesize avatarImage = _avatarImage;

- (UIImage*) avatarImage {
    if (_avatarImage != nil) {
        return _avatarImage;
    }
    _avatarImage = self.avatar != nil ? [UIImage imageWithData: self.avatar] : [UIImage imageNamed: @"avatar_default_contact"];

    return _avatarImage;
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
        myResult = [rsa getPeerKeyRef:self.clientId];
        if (myResult == nil) {
            NSLog(@"Contact:getPublicKeyRef: failed.");
        }
    }
    return myResult;
}

@end
