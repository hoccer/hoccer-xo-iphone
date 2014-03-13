//
//  GroupMembership.m
//  QRCodeEncoderObjectiveCAtGithub
//
//  Created by David Siegel on 15.05.13.
//
//

#import "GroupMembership.h"
#import "Contact.h"
#import "Group.h"
#import "HXOBackend.h"
#import "CCRSA.h"
#import "EC.h"
#import "NSData+Base64.h"


@implementation GroupMembership

@dynamic role;
@dynamic state;
@dynamic group;
@dynamic contact;
@dynamic ownGroupContact;
@dynamic lastChanged;
@dynamic cipheredGroupKey;
@dynamic distributedCipheredGroupKey;
@dynamic distributedGroupKey;
@dynamic memberKeyId;

@dynamic cipheredGroupKeyString;
@dynamic distributedCipheredGroupKeyString;
@dynamic lastChangedMillis;

@synthesize keySettingInProgress;

#if 0
- (void)didChangeValueForKey:(NSString *)key {
    [super didChangeValueForKey:key];
    NSLog(@"Groupmembership changed for key '%@'",key);

    if ([key isEqualToString:@"contact"]) {
        if (self.contact == nil) {
            NSLog(@"Groupmembership contact changed to nil: %@",[NSThread callStackSymbols]);
        }
    }
}
#endif

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSData *) calcCipheredGroupKey {
    if ([HXOBackend use_elliptic_curves]) {
        return [self calcCipheredGroupKeyEC];
    } else {
        return [self calcCipheredGroupKeyRSA];
    }
}

- (NSData *) decryptedGroupKey {
    if ([HXOBackend use_elliptic_curves]) {
        return [self decryptedGroupKeyEC];
    } else {
        return [self decryptedGroupKeyRSA];
    }
}

- (NSData *) calcCipheredGroupKeyRSA {
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.contact getPublicKeyRef];
    CCRSA * rsa = [CCRSA sharedInstance];
    //NSLog(@"self.group.groupKey=%@",[self.group.groupKey asBase64EncodedString]);
    return [rsa encryptWithKey:myReceiverKey plainData:self.group.groupKey];
}

- (NSData *) decryptedGroupKeyRSA {
    if (![self.group isEqual:self.contact]) {
        NSLog(@"ERROR:Group key won't be encrypted for me - must not call this function on other group members except me, contact nick=%@ contact.clientId = %@, group nick=%@, group.clientId = %@", self.contact.nickName, self.contact.clientId ,self.group.nickName, self.group.clientId);
        return nil;
    }
    if (self.cipheredGroupKey == nil || self.cipheredGroupKey.length == 0) {
        NSLog(@"ERROR:No Group key for me yet");
        return nil;
    }
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:self.memberKeyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR:group member key id does not match my own key");
        return nil;
    }
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:self.cipheredGroupKey];
    return theClearTextKey;
}

- (NSData *) calcCipheredGroupKeyEC {
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.contact getPublicKeyRefEC];
    EC * ec = [EC sharedInstance];
    //NSLog(@"self.group.groupKey=%@",[self.group.groupKey asBase64EncodedString]);
    return [ec encryptWithKey:myReceiverKey plainData:self.group.groupKey];
}

- (NSData *) decryptedGroupKeyEC {
    if (![self.group isEqual:self.contact]) {
        NSLog(@"ERROR:Group key won't be encrypted for me - must not call this function on other group members except me, contact nick=%@ contact.clientId = %@, group nick=%@, group.clientId = %@", self.contact.nickName, self.contact.clientId ,self.group.nickName, self.group.clientId);
        return nil;
    }
    if (self.cipheredGroupKey == nil || self.cipheredGroupKey.length == 0) {
        NSLog(@"ERROR:No Group key for me yet");
        return nil;
    }
    // get public key of receiver first
    EC * ec = [EC sharedInstance];
    SecKeyRef myPrivateKeyRef = [ec getPrivateKeyRef];
    NSData * theClearTextKey = [ec decryptWithKey:myPrivateKeyRef cipherData:self.cipheredGroupKey];
    return theClearTextKey;
}

-(NSString*) cipheredGroupKeyString {
    return [self.cipheredGroupKey asBase64EncodedString];
}

-(void) setCipheredGroupKeyString:(NSString*) theB64String {
    self.cipheredGroupKey = [NSData dataWithBase64EncodedString:theB64String];
}

-(NSString*) distributedCipheredGroupKeyString {
    return [self.distributedCipheredGroupKey asBase64EncodedString];
}

-(void) setDistributedCipheredGroupKeyString:(NSString*) theB64String {
    self.distributedCipheredGroupKey = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSDictionary*) rpcKeys {
    return @{ @"role"         : @"role",
              @"state"        : @"state",
              @"lastChanged"  : @"lastChangedMillis",
              @"encryptedGroupKey": @"cipheredGroupKeyString",
              @"memberKeyId"  : @"memberKeyId"
              };
}

@end

//public class TalkGroupMember {
//    public static final String ROLE_NONE = "none";
//    public static final String ROLE_ADMIN = "admin";
//    public static final String ROLE_MEMBER = "member";
//
//  String groupId;
//  String clientId;
//  String role;
//  String state;
//  String memberKeyId;
//  String encryptedGroupKey;
//  Date lastChanged;
//}