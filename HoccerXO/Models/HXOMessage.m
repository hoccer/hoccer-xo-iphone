//
//  Message.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOMessage.h"
#import "Delivery.h"
#import "Crypto.h"
#import "NSData+Base64.h"
#import "NSData+CommonCrypto.h"
#import "NSString+StringWithData.h"
#import "HXOBackend.h"
#import "Group.h"

@implementation HXOMessage

@dynamic isOutgoing;
@dynamic body;
@dynamic timeSent;
@dynamic timeReceived;
@dynamic timeAccepted;
@dynamic timeSection;
@dynamic isRead;
@dynamic messageId;
@dynamic messageTag;
@dynamic salt;

@dynamic contact;
@dynamic attachment;
@dynamic deliveries;
@dynamic saltString;


@synthesize cryptoKey = _cryptoKey;

@dynamic bodyCipherText;


-(NSData*) cryptoKey {
    if (_cryptoKey == nil) {
        if ([self.isOutgoing isEqualToNumber: @YES]) {
            [self setupOutgoingEncryption];
        } else {
            // get the key from the incoming delivery object
            Delivery * myDelivery = (Delivery*)[self.deliveries anyObject];
            // NSLog(@"myDelivery  =%@", myDelivery);
            NSData * key = [myDelivery keyCleartext];
            if (self.salt.length == key.length) {
                _cryptoKey = [HXOMessage XOR:key with:self.salt];
            } else {
                _cryptoKey = key;
            }
            // NSLog(@"message  cryptoKey=%@", _cryptoKey);
        }
    }
    return _cryptoKey;
}

-(void) setCryptoKey:(NSData*) theKey {
    _cryptoKey = theKey;
    if ([self.contact.type isEqualToString:@"Group"]) {
        //do not put keys into the delivery, the server will do that
        for (Delivery * d in self.deliveries) {
            d.keyCiphertext = [@"none" dataUsingEncoding:NSUTF8StringEncoding];
        }
    } else {
        // set an encrypted key into every delivery
        for (Delivery * d in self.deliveries) {
            d.keyCleartext = theKey;
        }
    }
}

- (NSString*) bodyCiphertext {
    if (self.body == nil) {
        return nil;
    }
    return [self encryptString: self.body];
}
 
-(void) setBodyCiphertext:(NSString*) theB64String {
     self.body = [self decryptString:theB64String];
}

- (NSString *)encryptString: (NSString *)string {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    // NSLog(@"encryptString data=%@", data);
    NSData *encrypted = [self encrypt:data];
    // NSLog(@"encryptString encripted=%@", encripted);
    return [encrypted asBase64EncodedString];
}

- (NSString *)decryptString: (NSString *)string {
    NSData *data = [NSData dataWithBase64EncodedString:string];
    // NSLog(@"decryptString:data crypted=%@", data);
    NSData *decrypted = [self decrypt:data];
    // NSLog(@"decryptString: decrypted=%@", decrypted);
    return [NSString stringWithData:decrypted usingEncoding:NSUTF8StringEncoding];
}

- (NSData *)encrypt:(NSData *)data {
    return [data AES256EncryptedDataUsingKey:self.cryptoKey error:nil];
}

- (NSData *)decrypt:(NSData *)data {
    return [data decryptedAES256DataUsingKey:self.cryptoKey error:nil];
}

- (void) setupOutgoingEncryption {
    if ([self.contact.type isEqualToString:@"Group"]) {
        self.salt =  [AESCryptor random256BitKey];
        Group * group = (Group*)self.contact;
        [self setCryptoKey:[HXOMessage XOR:group.groupKey with:self.salt]];
    } else {
        [self setCryptoKey: [AESCryptor random256BitKey]];
    }
}

+ (NSData *) XOR:(NSData*)a with:(NSData*)b {
    if (a.length != b.length) {
        NSLog(@"ERROR: XOR: a.length != b.length");
        return nil;
    }
    const uint8_t *a_bytes = (uint8_t *)[a bytes];
    const uint8_t *b_bytes = (uint8_t *)[b bytes];
    NSMutableData * result = [NSMutableData dataWithLength:a.length];
    uint8_t *result_bytes = (uint8_t *)[result bytes];
    for (int i = 0; i < a.length; ++i) {
        result_bytes[i] = a_bytes[i] ^ b_bytes[i];
    }
    return result;
}


- (NSNumber*) timeSentMillis {
    return [HXOBackend millisFromDate:self.timeSent];
}

- (void) setTimeSentMillis:(NSNumber*) milliSecondsSince1970 {
    self.timeSent = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSNumber*) timeAcceptedMillis {
    return [HXOBackend millisFromDate:self.timeAccepted];
}

- (void) setTimeAcceptedMillis:(NSNumber*) milliSecondsSince1970 {
    self.timeAccepted = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

-(NSString*) saltString {
    return [self.salt asBase64EncodedString];
}

-(void) setSaltString:(NSString*) theB64String {
    self.salt = [NSData dataWithBase64EncodedString:theB64String];
}

- (void) setTimeAccepted:(NSDate *)newTimeAccepted {
    NSDate * oldTimeAccepted = self.timeAccepted;
    if (![newTimeAccepted isEqualToDate:oldTimeAccepted]) {
        [self willChangeValueForKey:@"timeAccepted"];
        [self setPrimitiveValue: newTimeAccepted forKey: @"timeAccepted"];
        [self didChangeValueForKey:@"timeAccepted"];
        [HXOBackend adjustTimeSectionsForMessage:self];
    }
}


- (NSDictionary*) rpcKeys {
    return @{
             @"body": @"bodyCiphertext",
             @"messageId": @"messageId",
             @"messageTag": @"messageTag",
             @"senderId": @"contact.clientId",
             @"attachment": @"attachment.attachmentJsonStringCipherText",
             @"salt": @"saltString",
             @"timeSent": @"timeSentMillis" // our own time stamp
             };
}

@end
