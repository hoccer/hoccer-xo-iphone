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
#import "CCRSA.h"

// TODO: a model accessing the theme? get rid of that...
#import "HXOUI.h"

#import <CommonCrypto/CommonHMAC.h>

@implementation HXOMessage

@dynamic isOutgoingFlag;
@dynamic body;
@dynamic timeSent;
@dynamic timeReceived;
@dynamic timeAccepted;
@dynamic timeSection;
@dynamic isReadFlag;
@dynamic messageId;
@dynamic messageTag;
@dynamic salt;
@dynamic outgoingCryptoKey;
@dynamic attachmentFileId;
@dynamic senderId;
@dynamic sourceMAC;
@dynamic destinationMAC;
@dynamic signature;
@dynamic sharedKeyId;
@dynamic sharedKeyIdSalt;

@dynamic contact;
@dynamic attachment;
@dynamic deliveries;
@dynamic saltString;
@dynamic sourceMACString;
@dynamic signatureString;
@dynamic sharedKeyIdString;
@dynamic sharedKeyIdSaltString;

@dynamic cachedLandscapeCellHeight;
@dynamic cachedPortraitCellHeight;
@dynamic cachedBuildNumber;
@dynamic cachedMessageFontSize;
@dynamic cachedCellHeight;

@dynamic isOutgoing;
@dynamic isRead;

@dynamic isIncoming;

@synthesize cryptoKey = _cryptoKey;

@dynamic bodyCiphertext;


#define KEY_DEBUG NO

-(BOOL)isIncoming {
    return !self.isOutgoingFlag.boolValue;
}

-(BOOL)isOutgoing {
    return self.isOutgoingFlag.boolValue;
}

-(void)setIsOutgoing:(BOOL)isOutgoing {
    if (isOutgoing) {
        self.isOutgoingFlag = @YES;
    }else {
        self.isOutgoingFlag = @NO;
    }
}

-(BOOL)isRead {
    return self.isReadFlag.boolValue;
}

-(void)setIsRead:(BOOL)isRead {
    if (isRead) {
        self.isReadFlag = @YES;
    }else {
        self.isReadFlag = @NO;
    }
}

- (NSSet*) deliveriesFailed {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isFailure;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesSeen {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isSeen;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesUnseen {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isUnseen;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesPrivate {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isPrivate;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesDelivered {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isDelivered;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesNew {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isStateNew;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesDelivering {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isStateDelivering;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesPending {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isPending;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesAttachmentsReceived {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isAttachmentReceived;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesAttachmentsFailed {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isAttachmentFailure;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesAttachmentsPending {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isAttachmentPending;
    }];
    return theMemberSet;
}

- (NSSet*) deliveriesAttachmentsMissing {
    NSSet * theMemberSet = [self.deliveries objectsPassingTest:^BOOL(Delivery* obj, BOOL *stop) {
        return obj.isMissingAttachment;
    }];
    return theMemberSet;
}


-(CGFloat) cachedCellHeight {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    double messageFontSize = [HXOUI theme].messageFont.pointSize;
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
    self.cachedMessageFontSize = [HXOUI theme].messageFont.pointSize;
    self.cachedBuildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
    
    if (orientation == UIInterfaceOrientationPortrait) {
        self.cachedPortraitCellHeight = height;
    } else {
        self.cachedLandscapeCellHeight = height;
    }
}


-(NSData*) cryptoKey {
    if (_cryptoKey == nil) {
        if (self.isOutgoing) {
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
            if (KEY_DEBUG) {NSLog(@"message cryptoKey=%@", _cryptoKey);}
        }
    }
    if (KEY_DEBUG) {NSLog(@"returning message cryptoKey=%@", _cryptoKey);}
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
            // [group syncKeyWithMembership];
            NSData * computedId = [Crypto calcSymmetricKeyId:group.groupKey withSalt:group.sharedKeyIdSalt];
            if (KEY_DEBUG) NSLog(@"HXOMessage:setupOutgoingEncryption: using group key %@ with stored id %@ computed id %@",group.groupKey,group.sharedKeyId,computedId);
            if (![computedId isEqualToData:group.sharedKeyId]) {
                NSLog(@"ERROR: HXOMessage:setupOutgoingEncryption: stored id %@ does not match computed id %@",group.sharedKeyId,computedId);
            }
            self.outgoingCryptoKey = [Crypto XOR:group.groupKey with:self.salt];
        } else {
            self.outgoingCryptoKey = [Crypto random256BitKey];
        }
    } else {
        if (KEY_DEBUG) NSLog(@"HXOMessage:setupOutgoingEncryption: (re)using key %@",self.outgoingCryptoKey);
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

-(NSString*) sourceMACString {
    return [self.sourceMAC asBase64EncodedString];
}

-(void) setSourceMACString:(NSString*) theB64String {
    self.sourceMAC = [NSData dataWithBase64EncodedString:theB64String];
}

-(NSString*) signatureString {
    return [self.signature asBase64EncodedString];
}

-(void) setSignatureString:(NSString*) theB64String {
    self.signature = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSString*) sharedKeyIdString {
    return [self.sharedKeyId asBase64EncodedString];
}

- (void) setSharedKeyIdString:(NSString*) theB64String {
    self.sharedKeyId = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSString*) sharedKeyIdSaltString {
    return [self.sharedKeyIdSalt asBase64EncodedString];
}

- (void) setSharedKeyIdSaltString:(NSString*) theB64String {
    self.sharedKeyIdSalt = [NSData dataWithBase64EncodedString:theB64String];
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

-(void) printHash:(CC_SHA256_CTX *) ctx {
    NSData * d = [NSData dataWithBytes:&ctx->hash length:32];
    NSLog(@"hash=%@",[d asBase64EncodedString]);
}

// computes a SHA256 hash over body
- (NSData*)computeHMAC {
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);

    //NSData * tagData = [self.messageTag dataUsingEncoding:NSUTF8StringEncoding];
    //CC_SHA256_Update(&ctx,[tagData bytes],[tagData length]);

    NSData * senderData = [self.senderId dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[senderData bytes],[senderData length]);

#ifdef DEBUG_HMAC
    NSLog(@"checked sender='%@' len=%d", [NSString stringWithData:senderData usingEncoding:NSUTF8StringEncoding], [senderData length]);
    [self printHash:&ctx];
#endif
    
    NSData * timeSentData = [[self.timeSentMillis stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[timeSentData bytes],[timeSentData length]);
#ifdef DEBUG_HMAC
    NSLog(@"checked timeSentMillis='%@' len=%d", [NSString stringWithData:timeSentData usingEncoding:NSUTF8StringEncoding], [timeSentData length]);
    [self printHash:&ctx];
#endif

    NSData * bodyData = [self.bodyCiphertext dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA256_Update(&ctx,[bodyData bytes],[bodyData length]);
#ifdef DEBUG_HMAC
    NSLog(@"checked body='%@' len=%d", [NSString stringWithData:bodyData usingEncoding:NSUTF8StringEncoding], [bodyData length]);
    [self printHash:&ctx];
#endif

    if (self.attachment != nil) {
        NSData * attachmentData;
        if (self.attachment.origCryptedJsonString != nil) {
            attachmentData = [self.attachment.origCryptedJsonString dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            attachmentData = [self.attachment.attachmentJsonStringCipherText dataUsingEncoding:NSUTF8StringEncoding];
        }
        CC_SHA256_Update(&ctx,[attachmentData bytes],[attachmentData length]);
#ifdef DEBUG_HMAC
        NSLog(@"checked attachment='%@' len=%d", [NSString stringWithData:attachmentData usingEncoding:NSUTF8StringEncoding], [attachmentData length]);
        [self printHash:&ctx];
#endif
       
        //NSData * fileIdData = [self.attachmentFileId dataUsingEncoding:NSUTF8StringEncoding];
        //CC_SHA256_Update(&ctx,[fileIdData bytes],[fileIdData length]);
#ifdef DEBUG_HMAC
        NSLog(@"checked fileId='%@' len=%d", [NSString stringWithData:fileIdData usingEncoding:NSUTF8StringEncoding], [fileIdData length]);
        [self printHash:&ctx];
#endif
    }

    if (self.salt != nil && self.salt.length > 0) {
        NSData * saltData = [self.saltString dataUsingEncoding:NSUTF8StringEncoding];
        CC_SHA256_Update(&ctx,[saltData bytes],[saltData length]);
#ifdef DEBUG_HMAC
        NSLog(@"checked salt='%@' len=%d", [NSString stringWithData:saltData usingEncoding:NSUTF8StringEncoding], [saltData length]);
        [self printHash:&ctx];
#endif
    }

    NSMutableData * result = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final([result mutableBytes], &ctx);
#ifdef DEBUG_HMAC
    [self printHash:&ctx];
#endif
    
    return result;
}

- (void)sign {
    self.signature = [CCRSA makeSignatureOf:self.sourceMAC withPrivateKey:[[CCRSA sharedInstance] getPrivateKeyRef]];
}


- (BOOL)verifySignatureWithPublicKey:(SecKeyRef)publicKey {
    // TODO: verify destinationMAC when we actually transfer signature
    return [CCRSA verifySignature:self.signature forHash:self.sourceMAC withPublicKey:publicKey];
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
             @"hmac":@"sourceMACString",
             @"signature":@"signatureString",
             @"sharedKeyId":@"sharedKeyIdString",
             @"sharedKeyIdSalt":@"sharedKeyIdSaltString"
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
