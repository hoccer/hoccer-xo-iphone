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
@dynamic timeStamp;
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
    NSData *encripted = [self encrypt:data];
    // NSLog(@"encryptString encripted=%@", encripted);
    return [encripted asBase64EncodedString];
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

/* maybe not needed
@synthesize cryptoKeyString;

-(NSString*) cryptoKeyString {
    return [self.cryptoKey asBase64EncodedString];
}

-(void) setCryptokeyString:(NSString*) theB64String {
    self.cryptoKey = [NSData dataWithBase64EncodedString:theB64String];
}
*/

- (NSDictionary*) rpcKeys {
    return @{
              @"body": @"bodyCiphertext", // use this line to encrypt
              // @"body": @"body",        // use this line to disable body encryption
              @"messageId": @"messageId",
              @"senderId": @"contact.clientId",
              @"attachmentSize": @"attachment.contentSize",
              @"attachmentMediaType": @"attachment.mediaType",
              @"attachmentMimeType": @"attachment.mimeType",
              @"attachmentAspectRatio": @"attachment.aspectRatio",
              @"attachmentUrl": @"attachment.remoteURL"
            };
}

- (void) setupOutgoingEncryption {
    [self setCryptoKey: [AESCryptor random256BitKey]];
}



@end
