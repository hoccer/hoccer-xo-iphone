//
//  Delivery.m
//  HoccerTalk
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Delivery.h"
#import "Contact.h"
#import "TalkMessage.h"
#import "NSData_Base64Extensions.h"
#import "RSA.h"


@implementation Delivery

@dynamic state;
@dynamic message;
@dynamic receiver;
@dynamic keyCiphertext;
@dynamic keyCiphertextString;
@dynamic keyCleartext;

-(NSString*) keyCiphertextString {
    return [self.keyCiphertext asBase64EncodedString];
}

-(void) setKeyCiphertextString:(NSString*) theB64String {
    self.keyCiphertext = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSDictionary*) rpcKeys {
    return @{ @"state"     : @"state",
              @"receiverId": @"receiver.clientId",
              @"messageTag": @"message.messageTag",
              @"messageId" : @"message.messageId",
              @"keyCiphertext" : @"keyCiphertextString"
              };
}

+ (NSString*) stateNew        { return @"new";        }
+ (NSString*) stateDelivering { return @"delivering"; }
+ (NSString*) stateDelivered  { return @"delivered";  }
+ (NSString*) stateFailed     { return @"failed";     }


// this function will yield the plaintext the keyCiphertext by decrypting it with the private key
- (NSData *) keyCleartext {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        return nil; // can not decrypt outgoing key
    }
    if (![self.state isEqualToString:[Delivery stateNew]]) {
        return nil;
    }
    if (self.message.cryptoKey == nil) {
        return nil;
    }
    RSA * rsa = [RSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRef];
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:self.keyCiphertext];
    return theClearTextKey;
}

// this function will set the the keyCiphertext by encrypting the theMessageKey with the public key of the receiver
- (void) setKeyCleartext:(NSData *) theMessageKey {
    self.keyCiphertext = nil;
    // check a lot of preconditions just in case...
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
        return;
    }
    if (![self.state isEqualToString:[Delivery stateNew]]) {
        return;
    }
    if (self.receiver == nil) {
        return;
    }
    if (self.message.cryptoKey == nil) {
        return;
    }
    
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.receiver getPublicKeyRef];
    
    RSA * rsa = [RSA sharedInstance];
    self.keyCiphertext = [rsa encryptWithKey:myReceiverKey plainData:theMessageKey];
}

- (BOOL) setupKeyCiphertext {
    self.keyCleartext = self.message.cryptoKey;
    if (self.keyCiphertext != nil) {
        return YES;
    }
    return NO;
}

@end
