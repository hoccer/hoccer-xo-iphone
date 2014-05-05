//
//  Delivery.m
//  HoccerXO
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Delivery.h"
#import "Contact.h"
#import "HXOMessage.h"
#import "NSData+Base64.h"
#import "CCRSA.h"

#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "HXOBackend.h" // for class crypto methods
#import "Group.h"

NSString * const kDeliveryStateNew        = @"new";
NSString * const kDeliveryStateDelivering = @"delivering";
NSString * const kDeliveryStateDelivered  = @"delivered";
NSString * const kDeliveryStateConfirmed  = @"confirmed";
NSString * const kDeliveryStateFailed     = @"failed";

@implementation Delivery

@dynamic state;
@dynamic message;
@dynamic receiver;
@dynamic sender;
@dynamic group;
@dynamic keyCiphertext;
@dynamic keyCiphertextString;
@dynamic keyCleartext;
@dynamic receiverKeyId;
@dynamic timeChanged;
@dynamic timeChangedMillis;
@dynamic keyId;

-(NSString*) keyCiphertextString {
    return [self.keyCiphertext asBase64EncodedString];
}

-(void) setKeyCiphertextString:(NSString*) theB64String {
    // NSLog(@"Delivery: setKeyCiphertextString: ‘%@‘", theB64String);
    if ([theB64String isKindOfClass:[NSString class]]) {
        self.keyCiphertext = [NSData dataWithBase64EncodedString:theB64String];
        // NSLog(@"Delivery: setKeyCiphertext = : ‘%@‘",  self.keyCiphertext);
    } else {
        NSLog(@"Delivery: setKeyCiphertextString: nil key in message");
    }
}

-(NSString*) receiverKeyId {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        // for outgoing deliveries
        if ([self.message.contact.type isEqualToString:@"Group"]) {
            self.keyId = @"0000000000000000";  // sent arbitrary string, will be substituted by server
        } else {
            self.keyId = self.receiver.publicKeyId;
        }
        return self.keyId;
    } else {
        // for incoming deliveries
        return self.keyId;
    }
}

// for incoming deliveries
-(void) setReceiverKeyId:(NSString *) theKeyId {
    self.keyId = theKeyId;
}


// this function will yield the plaintext the keyCiphertext by decrypting it with the private key
- (NSData *) keyCleartext {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        return nil; // can not decrypt outgoing key
    }
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:self.receiverKeyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR: I have no private key for key id %@", self.receiverKeyId);
        return nil;
    }
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
    if (![self.state isEqualToString:kDeliveryStateNew]) {
        return;
    }
    if (self.receiver == nil) {
        return;
    }
    if (theMessageKey == nil) {
        return;
    }
    
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.receiver getPublicKeyRef];

    // Since we support custom key sizes it is very well possible to end up without a public key.
    // Because we might have more than one delivery and this is called in a setter in a setter ... in a setter
    // we tag the delivery as failed here. The backend respects this by not sending the message. [DS]
    if ( ! myReceiverKey) {
        self.state = kDeliveryStateFailed;
        return;
    }
    
    CCRSA * rsa = [CCRSA sharedInstance];
    self.keyCiphertext = [rsa encryptWithKey:myReceiverKey plainData:theMessageKey];
}


- (BOOL) setupKeyCiphertext {
    self.keyCleartext = self.message.cryptoKey;
    if (self.keyCiphertext != nil) {
        return YES;
    }
    return NO;
}


- (NSNumber*) timeChangedMillis {
    return [HXOBackend millisFromDate:self.timeChanged];
}

- (void) setTimeChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.timeChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}


- (NSDictionary*) rpcKeys {
    return @{ @"state"         : @"state",
//              @"receiverId"    : @"receiver.clientId",
//              @"groupId"       : @"group.clientId",
//              @"senderId"      : @"sender.clientId",
              @"messageTag"    : @"message.messageTag",
              @"messageId"     : @"message.messageId",
              @"timeAccepted"  : @"message.timeAcceptedMillis",
              @"timeChanged"   : @"timeChangedMillis",
              @"keyId"         : @"receiverKeyId",
              @"keyCiphertext" : @"keyCiphertextString"
              };
}

@end
