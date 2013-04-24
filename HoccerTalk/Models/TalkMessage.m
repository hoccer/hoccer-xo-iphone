//
//  Message.m
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TalkMessage.h"
#import "Delivery.h"
#import "Crypto.h"
#import "NSData+Base64.h"
#import "NSData+CommonCrypto.h"
#import "NSString+StringWithData.h"

@implementation TalkMessage

@dynamic isOutgoing;
@dynamic body;
@dynamic timeSend;
@dynamic timeAccepted;
@dynamic timeSection;
@dynamic isRead;
@dynamic messageId;
@dynamic messageTag;

@dynamic contact;
@dynamic attachment;
@dynamic deliveries;

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
            _cryptoKey = [myDelivery keyCleartext];
            // NSLog(@"message  cryptoKey=%@", _cryptoKey);
        }
    }
    return _cryptoKey;
}

-(void) setCryptoKey:(NSData*) theKey {
    _cryptoKey = theKey;
    for (Delivery * d in self.deliveries) {
        d.keyCleartext = theKey;
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


- (NSDictionary*) rpcKeys {
    return @{
             @"body": @"bodyCiphertext", // use this line to encrypt
             @"messageId": @"messageId",
             @"senderId": @"contact.clientId",
             @"attachment": @"attachment.attachmentJsonStringCipherText",
             };
}

- (void) setupOutgoingEncryption {
    [self setCryptoKey: [AESCryptor random256BitKey]];
}

- (void) setTimeAccepted:(id)timeAccepted {
    if ([timeAccepted isKindOfClass: [NSNumber class]]) {
        timeAccepted = [NSDate dateWithTimeIntervalSince1970: [timeAccepted doubleValue] / 1000];
    }
    [self willChangeValueForKey:@"timeAccepted"];
    [self setPrimitiveValue: timeAccepted forKey: @"timeAccepted"];
    [self didChangeValueForKey:@"timeAccepted"];
}



@end
