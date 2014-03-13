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
#import "HXOUserDefaults.h"
#import "Attachment.h"
#import "RSA.h"

#import <CommonCrypto/CommonHMAC.h>

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
@dynamic outgoingCryptoKey;
@dynamic attachmentFileId;
@dynamic senderId;
@dynamic hmac;

@dynamic contact;
@dynamic attachment;
@dynamic deliveries;
@dynamic saltString;

@dynamic cachedLandscapeCellHeight;
@dynamic cachedPortraitCellHeight;
@dynamic cachedBuildNumber;
@dynamic cachedMessageFontSize;
@dynamic cachedCellHeight;

@synthesize cryptoKey = _cryptoKey;

@dynamic bodyCiphertext;
@dynamic hmacString;


#define KEY_DEBUG NO

-(CGFloat) cachedCellHeight {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    double messageFontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
#ifdef USE_BUILD_NUMBER_CACHE
    NSString * buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
#endif
    if (messageFontSize == self.cachedMessageFontSize
#ifdef USE_BUILD_NUMBER_CACHE
        && [buildNumber isEqualToString:self.cachedBuildNumber]
#endif
        ) {
        if (orientation == UIInterfaceOrientationPortrait) {
            if (self.cachedPortraitCellHeight != 0) {
                return self.cachedPortraitCellHeight;
            }
        } else {
            if (self.cachedLandscapeCellHeight != 0) {
                return self.cachedLandscapeCellHeight;
            }
        }
    }
    return 0.0;
}

-(void) setCachedCellHeight:(CGFloat)height {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    self.cachedMessageFontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
    self.cachedBuildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
    
    if (orientation == UIInterfaceOrientationPortrait) {
        self.cachedPortraitCellHeight = height;
    } else {
        self.cachedLandscapeCellHeight = height;
    }
}


-(NSData*) cryptoKey {
    if (_cryptoKey == nil) {
        if ([self.isOutgoing isEqualToNumber: @YES]) {
            [self setupOutgoingEncryption];
        } else {
            // get the key from the incoming delivery object
            Delivery * myDelivery = (Delivery*)[self.deliveries anyObject];
            if (KEY_DEBUG) {NSLog(@"myDelivery=%@", myDelivery);}
            NSData * key = [myDelivery keyCleartext];
            if (KEY_DEBUG) {NSLog(@"key=%@", key);}
            if (KEY_DEBUG) {NSLog(@"salt=%@", self.salt);}
            if (self.salt.length == key.length) {
                _cryptoKey = [Crypto XOR:key with:self.salt];
            } else {
                _cryptoKey = key;
            }
            if (KEY_DEBUG) {NSLog(@"message  cryptoKey=%@", _cryptoKey);}
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
    if (self.outgoingCryptoKey == nil) {
        if ([self.contact.type isEqualToString:@"Group"]) {
            self.salt =  [Crypto random256BitKey];
            Group * group = (Group*)self.contact;
            self.outgoingCryptoKey = [Crypto XOR:group.groupKey with:self.salt];
        } else {
            self.outgoingCryptoKey = [Crypto random256BitKey];
        }
    }
    [self setCryptoKey:self.outgoingCryptoKey];
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
    if (KEY_DEBUG) NSLog(@"setSaltString: %@", theB64String);
    self.salt = [NSData dataWithBase64EncodedString:theB64String];
}

-(NSString*) hmacString {
    return [self.hmac asBase64EncodedString];
}

-(void) setHmacString:(NSString*) theB64String {
    self.hmac = [NSData dataWithBase64EncodedString:theB64String];
}

-(NSString*) signatureString {
    return [self.signature asBase64EncodedString];
}

-(void) setSignatureString:(NSString*) theB64String {
    self.signature = [NSData dataWithBase64EncodedString:theB64String];
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

// computes a SHA256 hash over body
- (NSData*)computeHMAC {
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);

    {
    //NSData * tagData = [self.messageTag dataUsingEncoding:NSUTF8StringEncoding];
    //CC_SHA256_Update(&ctx,[tagData bytes],[tagData length]);
    }{
    NSData * senderData = [self.senderId dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[senderData bytes],[senderData length]);
    }{
    NSData * timeSentData = [[self.timeSentMillis stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[timeSentData bytes],[timeSentData length]);
    }{
    NSData * bodyData = [self.bodyCiphertext dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[bodyData bytes],[bodyData length]);
    }
    if (self.attachment != nil) {
        NSData * attachmentData = [self.attachment.attachmentJsonStringCipherText dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&ctx,[attachmentData bytes],[attachmentData length]);
        
        NSData * fileIdData = [self.attachmentFileId dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&ctx,[fileIdData bytes],[fileIdData length]);
    }
    
    if (self.salt != nil) {
        NSData * saltData = [self.saltString dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&ctx,[saltData bytes],[saltData length]);
    }
    
    NSMutableData * result = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final([result mutableBytes], &ctx);
    
    return result;
}

- (void)sign {
    self.signature = [RSA makeSignatureOf:self.hmac withPrivateKey:[[RSA sharedInstance] getPrivateKeyRef]];
}

- (BOOL)verifySignatureWithPublicKey:(SecKeyRef)publicKey {
    return [RSA verifySignature:self.signature forHash:self.hmac withPublicKey:publicKey];
}

- (NSDictionary*) rpcKeys {
    return @{
             @"salt": @"saltString",
             @"body": @"bodyCiphertext",
             @"messageId": @"messageId",
             @"messageTag": @"messageTag",
             @"senderId": @"senderId",
             @"attachment": @"attachment.attachmentJsonStringCipherText",
             @"timeSent": @"timeSentMillis", // our own time stamp
             @"attachmentFileId":@"attachmentFileId",
             @"hmac":@"hmacString",
             @"signature":@"signatureString"
             };
}

#pragma mark - HXOMessage UIActivityItemSource Protocol

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType {
    return @"public.text";
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    return self.body;
}
/*
- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
    
}

- (UIImage *)activityViewController:(UIActivityViewController *)activityViewController thumbnailImageForActivityType:(NSString *)activityType suggestedSize:(CGSize)size {
    
}
*/
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    return self.body;
}

@end
