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
#import "NSData+Base64.h"
#import "RSA.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"

NSString * const kDeliveryStateNew        = @"new";
NSString * const kDeliveryStateDelivering = @"delivering";
NSString * const kDeliveryStateDelivered  = @"delivered";
NSString * const kDeliveryStateConfirmed  = @"confirmed";
NSString * const kDeliveryStateFailed     = @"failed";

@implementation Delivery

@dynamic state;
@dynamic message;
@dynamic receiver;
@dynamic keyCiphertext;
@dynamic keyCiphertextString;
@dynamic keyCleartext;
@dynamic receiverKeyId;
@dynamic timeChanged;

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

// for outgoing deliveries
-(NSString*) receiverKeyId {
    return self.receiver.publicKeyId;
}

// for incoming deliveries
-(void) setReceiverKeyId:(NSString *) theKeyId {
    NSData * myKeyBits = [[RSA sharedInstance] getPublicKeyBits];
    NSData * myKeyId = [[myKeyBits SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
    
    if (![theKeyId isEqualToString:[myKeyId hexadecimalString]]) {
        NSLog(@"ERROR: incoming message was encrypted with a public key with id %@, but my key id is %@ - decryption will fail",theKeyId,[myKeyId hexadecimalString]);
    }
}

- (NSDictionary*) rpcKeys {
    return @{ @"state"         : @"state",
              @"receiverId"    : @"receiver.clientId",
              @"messageTag"    : @"message.messageTag",
              @"messageId"     : @"message.messageId",
              @"timeAccepted"  : @"message.timeAccepted",
              @"timeChanged"   : @"timeChanged",
              @"keyId"         : @"receiverKeyId",
              @"keyCiphertext" : @"keyCiphertextString"
              };
}


// this function will yield the plaintext the keyCiphertext by decrypting it with the private key
- (NSData *) keyCleartext {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        return nil; // can not decrypt outgoing key
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
    if (![self.state isEqualToString:kDeliveryStateNew]) {
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

- (void) setTimeChanged:(id)timeChanged {
    if ([timeChanged isKindOfClass: [NSNumber class]]) {
        timeChanged = [NSDate dateWithTimeIntervalSince1970: [timeChanged doubleValue] / 1000];
    }
    [self willChangeValueForKey:@"timeChanged"];
    [self setPrimitiveValue: timeChanged forKey: @"timeChanged"];
    [self didChangeValueForKey:@"timeChanged"];
}

@end
