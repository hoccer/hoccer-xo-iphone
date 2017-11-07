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
@property (nonatomic, strong) UNNotificationContent * originalContent;
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

NSString *
decryptMessage(NSDictionary* userInfo) {
    NSString * keyCiphertext = userInfo[@"keyCiphertext"];
    NSString * keyId = userInfo[@"keyId"];
    NSString * body = userInfo[@"body"];
    NSString * salt = [userInfo objectForKey:@"salt"];
    NSString * attachment = [userInfo objectForKey:@"attachment"];

    NSLog(@"keyCiphertext=%@, keyId=%@",keyCiphertext,keyId);
    NSData * keyCipherData = [NSData dataWithBase64EncodedString:keyCiphertext];
    NSData * theAESKey = decipherKey(keyCipherData, keyId, salt);
    NSData * bodyData = [NSData dataWithBase64EncodedString: body];
    NSLog(@"bodyData=%@",bodyData.hexadecimalString);
    NSLog(@"theAESKey=%@",theAESKey.hexadecimalString);

    NSError * error = nil;
    NSData * bodyDecrypted = [bodyData decryptedAES256DataUsingKey:theAESKey error: &error];
    if (bodyDecrypted != nil) {
        NSLog(@"bodyDecrypted=%@",bodyDecrypted.hexadecimalString);
    } else {
        NSLog(@"decrypt ERROR=%@", error);
    }
    NSString * bodyCleartext;
    if (bodyDecrypted) {
        bodyCleartext = [NSString stringWithData: bodyDecrypted usingEncoding:NSUTF8StringEncoding];
    }
    NSLog(@"bodyCleartext=%@", bodyCleartext);
    
    if (attachment != nil) {
        NSLog(@"attachment=%@",attachment);
        NSData * attachmentData = [NSData dataWithBase64EncodedString:attachment];
        NSData * attachmentDecrypted = [attachmentData decryptedAES256DataUsingKey:theAESKey error:nil];
        NSString * attachmentCleartext = [NSString stringWithData:attachmentDecrypted usingEncoding:NSUTF8StringEncoding];
        NSLog(@"attachmentCleartext=%@",attachmentCleartext);
        NSError * error;
        @try {
            id json = [NSJSONSerialization JSONObjectWithData: [attachmentCleartext dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
            if (json == nil) {
                NSLog(@"ERROR: JSON parse error: %@ on string %@", error.userInfo[@"NSDebugDescription"], attachmentCleartext);
            }
            if ([json isKindOfClass: [NSDictionary class]]) {
                // successfully suparsed attachment dictionary
                NSString * i18nKey = [NSString stringWithFormat: @"attachment_type_%@", json[@"mediaType"]];
                NSString * mediaType = NSLocalizedString(i18nKey, nil);
                bodyCleartext = [NSString stringWithFormat:@"%@ [%@]",bodyCleartext, mediaType];
                NSLog(@"bodyCleartext=%@",bodyCleartext);
            } else {
                NSLog(@"ERROR: attachment json not encoded as dictionary, json string = %@", attachmentCleartext);
            }
        } @catch (NSException * ex) {
            NSLog(@"ERROR: parsing json, jsonData = %@, ex=%@", attachmentCleartext, ex);
        }
    }
    return bodyCleartext;
}

@implementation NotificationService


- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.originalContent = request.content;

    UNMutableNotificationContent * decryptedContent = [self.originalContent mutableCopy];
    NSDictionary *userInfo = request.content.userInfo;
    NSString * sender = userInfo[@"sender"];
    NSString * group = [userInfo objectForKey:@"group"];
    NSUserDefaults * sharedData = [[NSUserDefaults alloc] initWithSuiteName: [self appGroupId]];

    if (group) {
        group = [sharedData objectForKey: [NSString stringWithFormat: @"nickName.group.%@", group]];
        if (group == nil) {
            return [self failGracefully];
        }
    }

    sender = [sharedData objectForKey: [NSString stringWithFormat: @"nickName.contact.%@", sender]];
    if (sender == nil) {
        return [self failGracefully];
    }

    decryptedContent.title = group != nil ? [NSString stringWithFormat: @"%@: %@", group, sender] : sender;

    decryptedContent.body = decryptMessage(userInfo);
    if (decryptedContent.body == nil) {
        return [self failGracefully];
    }


    // Debugging: Tag what we have as [modified]...
    // decryptedContent.title = [NSString stringWithFormat:@"[modified] %@", decryptedContent.title];
    
    self.contentHandler(decryptedContent);
}

- (void) failGracefully {
    UNMutableNotificationContent * content = [self.originalContent mutableCopy];
    content.title = @"";
    content.body = NSLocalizedString(@"apn_one_new_message", nil);
    if (content.badge != nil && content.badge.intValue != 1) {
        content.body = [NSString stringWithFormat: NSLocalizedString(@"apn_new_messages", nil), content.badge];
    }
    self.contentHandler(content);
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    [self failGracefully];
}

- (NSString*) appGroupId {
    NSString * groupIdSetting = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"HXOAppGroupId"];
    if (groupIdSetting != nil) {
        return groupIdSetting;
    }
    NSString * bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSMutableArray * slugs = [NSMutableArray arrayWithArray: [bundleId componentsSeparatedByString: @"."]];
    [slugs removeLastObject];
    [slugs insertObject: @"group" atIndex: 0];
    return [slugs componentsJoinedByString: @"."];
}

@end
