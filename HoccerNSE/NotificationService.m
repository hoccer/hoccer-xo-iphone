//
//  NotificationService.m
//  HoccerNSE
//
//  Created by David Siegel on 26.10.17.
//  Copyright © 2017 Hoccer GmbH. All rights reserved.
//

#import "NotificationService.h"

#import "Crypto.h"
#import "NSData+Base64.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "NSString+StringWithData.h"
#import "TinyCCRSA.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end


NSData * decipherKey(NSData * keyCipherdata, NSString* keyId, NSString* saltString) {
    
    TinyCCRSA * rsa = [TinyCCRSA sharedInstance];
    [rsa findKeyPairs];

    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:keyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR: I have no private key for key id %@", keyId);
        return nil;
    }
    NSLog(@"decipherKey with key id %@", myPrivateKeyRef);

    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:keyCipherdata];
    NSLog(@"decipherKey theClearTextKey is %@", theClearTextKey.hexadecimalString);

    if (saltString != nil && saltString.length > 0) {
        NSData * salt = [NSData dataWithBase64EncodedString:saltString];
        if (salt != nil && salt.length == theClearTextKey.length) {
            theClearTextKey = [Crypto XOR:theClearTextKey with:salt];
        }
    }
    return theClearTextKey;
}

@implementation NotificationService


- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    NSDictionary *userInfo = request.content.userInfo;
    NSString * keyCiphertext = userInfo[@"keyCiphertext"];
    NSString * keyId = userInfo[@"keyId"];
    NSString * body = userInfo[@"body"];
    NSString * sender = userInfo[@"sender"];
    NSString * salt = [userInfo objectForKey:@"salt"];
    NSString * group = [userInfo objectForKey:@"group"];

    NSLog(@"keyCiphertext=%@, keyId=%@",keyCiphertext,keyId);
    NSData * keyCipherData = [NSData dataWithBase64EncodedString:keyCiphertext];
    NSData * theAESKey = decipherKey(keyCipherData, keyId, salt);
    NSData * bodyData = [NSData dataWithBase64EncodedString:body];
    NSLog(@"bodyData=%@",bodyData.hexadecimalString);
    NSLog(@"theAESKey=%@",theAESKey.hexadecimalString);
    
    NSData * bodyDecrypted = [bodyData decryptedAES256DataUsingKey:theAESKey error:nil];
    NSLog(@"bodyDecrypted=%@",bodyDecrypted.hexadecimalString);

    NSString * bodyCleartext = [NSString stringWithData:bodyDecrypted usingEncoding:NSUTF8StringEncoding];
    NSLog(@"bodyCleartext=%@",bodyCleartext);

    if (group == nil) {
        self.bestAttemptContent.title = sender; // TODO: look up nickname for sender
    } else {
        self.bestAttemptContent.title = [NSString stringWithFormat:@"%@:%@", group, sender]; // TODO: look up nickname for sender
    }
    self.bestAttemptContent.body = bodyCleartext;
    // Modify the notification content here...
    self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.title];
    
    self.contentHandler(self.bestAttemptContent);
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    self.contentHandler(self.bestAttemptContent);
}

@end
