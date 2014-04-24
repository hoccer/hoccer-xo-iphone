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
#import "NSData+Base64.h"
#import "Crypto.h"
#import "UserProfile.h"


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
@dynamic keySupplier;

@dynamic cipheredGroupKeyString;
@dynamic distributedCipheredGroupKeyString;
@dynamic lastChangedMillis;
@dynamic sharedKeyId;
@dynamic sharedKeyIdSalt;

@dynamic sharedKeyIdString;
@dynamic sharedKeyIdSaltString;

@dynamic sharedKeyDate;
@dynamic sharedKeyDateMillis;

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

- (NSNumber*) sharedKeyDateMillis {
    return [HXOBackend millisFromDate:self.sharedKeyDate];
}

- (void) setSharedKeyDateMillis:(NSNumber*) milliSecondsSince1970 {
    self.sharedKeyDate = [HXOBackend dateFromMillis:milliSecondsSince1970];
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

- (NSData *) calcCipheredGroupKey {
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.contact getPublicKeyRef];
    CCRSA * rsa = [CCRSA sharedInstance];
    //NSLog(@"self.group.groupKey=%@",[self.group.groupKey asBase64EncodedString]);
    return [rsa encryptWithKey:myReceiverKey plainData:self.group.groupKey];
}

- (BOOL) hasCipheredGroupKey {
    if (self.cipheredGroupKey != nil && self.cipheredGroupKey.length > 0) {
        NSLog(@"hasCipheredGroupKey: YES");
        return YES;
    }
    NSLog(@"hasCipheredGroupKey: NO");
    return NO;
}

- (BOOL) hasLatestGroupKey {
    if (self.hasCipheredGroupKey) {
        if ([self.sharedKeyId isEqualToData:self.group.sharedKeyId]) {
            NSLog(@"Member:hasLatestGroupKey: YES (1)");
            return YES;
        } else {
            BOOL result = [self.sharedKeyDate compare:self.group.keyDate] == NSOrderedDescending;
            NSLog(@"Member:hasLatestGroupKey: %@", result ? @"YES (2)" : @"NO (2)");
            return result;
            // true if self.sharedKeyDate later than self.group.keyDate
        }
    }
    NSLog(@"Member:hasLatestGroupKey: NO (3)");
    return NO;
}

-(BOOL) hasValidGroupKey {
    if (!self.hasCipheredGroupKey) {
        NSLog(@"Member:hasValidGroupKey: NO (0)");
        return NO;
    }
    NSData * myDecryptedKey = [self decryptedGroupKey];
    NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:myDecryptedKey withSalt:self.sharedKeyIdSalt];
    if (myGroupKeyId == nil) {
        NSLog(@"GroupMembership hasValidGroupKey: nil id, self.groupKey = %@, self.sharedKeyIdSalt = %@", myDecryptedKey, self.sharedKeyIdSalt);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        NSLog(@"Member:hasValidGroupKey: NO (1)");
        return NO;
    }
    if (![myGroupKeyId isEqualToData:self.sharedKeyId]) {
        NSLog(@"GroupMembership hasValidGroupKey mismatch: stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        //NSLog(@"%@",[NSThread callStackSymbols]);
        NSLog(@"Member:hasValidGroupKey: NO (2)");
        return NO;
    }
    NSLog(@"Member:hasValidGroupKey: YES");
    return YES;
}

- (BOOL) isOwnMembership {
    return [self.group isEqual:self.contact];
}

- (NSString*)contactClientId {
    if (self.isOwnMembership) {
        return UserProfile.sharedProfile.clientId;
    } else {
        return self.contact.clientId;
    }
}

- (NSString*)contactPubKeyId {
    if (self.isOwnMembership) {
        return UserProfile.sharedProfile.publicKeyId;
    } else {
        return self.contact.publicKeyId;
    }
}

- (BOOL)contactHasPubKey {
    if (self.isOwnMembership) {
        BOOL result = UserProfile.sharedProfile.publicKey != nil;
        NSLog(@"Member(selfcontact):contactHasPubKey: %@", result ? @"YES" : @"NO");
        return result;
    } else {
        BOOL result = self.contact.hasPublicKey;
        NSLog(@"Member(%@):contactHasPubKey: %@", self.contact.clientId, result ? @"YES" : @"NO");
        return result;
    }
}

- (BOOL) hasGroupKeyCryptedWithLatestPublicKey {
    NSString * myKeyId = self.contactPubKeyId;
    BOOL result = self.memberKeyId != nil && myKeyId != nil && [self.memberKeyId isEqualToString:myKeyId];
    NSLog(@"Member:hasGroupKeyCryptedWithLatestPublicKey: %@", result ? @"YES" : @"NO");
    return result;
}

/*
- (BOOL) copyKeyFromGroup {
    if ([self hasCipheredGroupKey]) {
        self.cipheredGroupKey = [self calcCipheredGroupKey];
        self.sharedKeyIdSalt = self.group.sharedKeyIdSalt;
        NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:self.decryptedGroupKey withSalt:self.sharedKeyIdSalt];
        if (![myGroupKeyId isEqualToData:self.group.sharedKeyId]) {
            NSLog(@"ERROR:copyKeyFromGroup: something went wrong");
            return NO;
        }
        self.sharedKeyId = myGroupKeyId;
        self.memberKeyId = self.contact.publicKeyId;
        [self checkGroupKey];
        NSLog(@"Member:copyKeyFromGroup: YES");
        return YES;
    }
    NSLog(@"Member:copyKeyFromGroup: NO");
    return NO;
}
*/

- (void) updateKeyFromGroup {
    if (self.isOwnMembership) {
        // handle self contact
        NSString * myPublicKeyIdString = [[UserProfile sharedProfile] publicKeyId];
        CCRSA * rsa = [CCRSA sharedInstance];
        SecKeyRef myReceiverKey = [rsa getPublicKeyRef];
        self.cipheredGroupKey = [rsa encryptWithKey:myReceiverKey plainData:self.group.groupKey];
        self.memberKeyId = myPublicKeyIdString;
        self.sharedKeyId = self.group.sharedKeyId;
        self.sharedKeyIdSalt = self.group.sharedKeyIdSalt;
    } else {
        // handle other contact
        self.memberKeyId = self.contact.publicKeyId;
        self.cipheredGroupKey = [self calcCipheredGroupKey];
        self.sharedKeyId = self.group.sharedKeyId;
        self.sharedKeyIdSalt = self.group.sharedKeyIdSalt;
    }
}


/*
-(void) checkGroupKey {
    NSData * myGroupKeyId;
    NSString * name;
    if ([self.group isEqual:self.contact]) {
        myGroupKeyId = [Crypto calcSymmetricKeyId:self.decryptedGroupKey withSalt:self.sharedKeyIdSalt];
        name = @"SELF";
    } else {
        NSLog(@"Member id %@ checkGroupKey: using stored group key (and not member key) for id calculation, your mileage may vary", self.contact.clientId);
        myGroupKeyId = [Crypto calcSymmetricKeyId:self.group.groupKey withSalt:self.sharedKeyIdSalt];
        name = self.contact.nickName != nil ?  self.contact.nickName : self.contact.clientId;
    }
    if (![myGroupKeyId isEqualToData:self.sharedKeyId]) {
        NSLog(@"Member %@ checkGroupKey: stored id = %@, computed id = %@", name, self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        NSLog(@"%@",[NSThread callStackSymbols]);
        //@throw [NSException exceptionWithName: @"Membership checkGroupKeyFailure" reason: @"stored id does not match computed id" userInfo: nil];
    } else {
        NSLog(@"Member %@ checkGroupKey OK: stored id = %@, computed id = %@", name, self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);        
    }
}
*/

-(BOOL) checkGroupKeyTransfer:(NSString*)cipheredGroupKeyString withKeyId:(NSString*)keyIdString withSharedKeyId:(NSString*)sharedKeyIdString withSharedKeyIdSalt:(NSString*)sharedKeyIdSaltString {
    NSLog(@"checkGroupKeyTransfer: cipheredGroupKeyString = %@, keyIdString = %@, sharedKeyIdString=%@, sharedKeyIdSaltString=%@", cipheredGroupKeyString,keyIdString,sharedKeyIdString, sharedKeyIdSaltString);
    if (keyIdString == nil) {
        NSLog(@"Member checkGroupKeyTransfer: no key material received");
        return NO;
    }
    NSData * cipheredGroupKey =[NSData dataWithBase64EncodedString:cipheredGroupKeyString];
    NSData * myGroupKey = [self decryptGroupKey:cipheredGroupKey withMemberKeyId:keyIdString];
    if (myGroupKey == nil) {
        NSLog(@"Member checkGroupKeyTransfer: can't decode");
        return NO;
    }
    NSData * sharedKeyId =[NSData dataWithBase64EncodedString:sharedKeyIdString];
    NSData * sharedKeyIdSalt =[NSData dataWithBase64EncodedString:sharedKeyIdSaltString];
    NSData * myGroupKeyId = [Crypto calcSymmetricKeyId:myGroupKey withSalt:sharedKeyIdSalt];
    
    if (![myGroupKeyId isEqualToData:sharedKeyId]) {
        NSLog(@"Member checkGroupKeyTransfer: stored id = %@, computed id = %@", self.sharedKeyIdString, [myGroupKeyId asBase64EncodedString]);
        NSLog(@"%@",[NSThread callStackSymbols]);
        //@throw [NSException exceptionWithName: @"Membership checkGroupKeyFailure" reason: @"stored id does not match computed id" userInfo: nil];
        return NO;
    }
    return YES;
}

- (NSData *) decryptedGroupKey {
    if (![self.group isEqual:self.contact]) {
        NSLog(@"ERROR:Group key won't be encrypted for me - must not call this function on other group members except me, contact nick=%@ contact.clientId = %@, group nick=%@, group.clientId = %@", self.contact.nickName, self.contact.clientId ,self.group.nickName, self.group.clientId);
        NSLog(@"%@",[NSThread callStackSymbols]);
        return nil;
    }
    if (self.cipheredGroupKey == nil || self.cipheredGroupKey.length == 0) {
        NSLog(@"ERROR:No Group key for me yet");
        return nil;
    }
    return [self decryptGroupKey:self.cipheredGroupKey withMemberKeyId:self.memberKeyId];
}

- (NSData *)decryptGroupKey:(NSData*)cipheredGroupKey withMemberKeyId:(NSString*)memberKeyId {
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:memberKeyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR: decryptGroupKey: no private key for memberKeyId %@",memberKeyId);
        return nil;
    }
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:cipheredGroupKey];
    if ([HXOBackend isInvalid:theClearTextKey]) {
        NSLog(@"ERROR: decryptGroupKey: decryption yielded no valid key despite of memberKeyId was fine");
        return nil;
    }
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
              @"memberKeyId"  : @"memberKeyId",
              @"sharedKeyId"  : @"sharedKeyIdString",
              @"sharedKeyIdSalt" : @"sharedKeyIdSaltString",
              @"sharedKeyDate"  : @"sharedKeyDateMillis",
              @"keySupplier"  : @"keySupplier"              
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