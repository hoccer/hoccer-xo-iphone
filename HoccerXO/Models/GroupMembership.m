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
#import "RSA.h" 
#import "NSData+Base64.h"


@implementation GroupMembership

@dynamic role;
@dynamic state;
@dynamic group;
@dynamic contact;
@dynamic lastChanged;
@dynamic cipheredGroupKey;
@dynamic distributedCipheredGroupKey;

@dynamic cipheredGroupKeyString;
@dynamic distributedCipheredGroupKeyString;
@dynamic lastChangedMillis;

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSData *) calcCipheredGroupKey {
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.contact getPublicKeyRef];
    RSA * rsa = [RSA sharedInstance];
    //NSLog(@"self.group.groupKey=%@",[self.group.groupKey asBase64EncodedString]);
    return [rsa encryptWithKey:myReceiverKey plainData:self.group.groupKey];
}

- (NSData *) decryptedGroupKey {
    if (self.contact != nil) {
        NSLog(@"ERROR:Group key won't be encrypted for me - must not call this function on other group members except me");
        return nil;
    }
    if (self.cipheredGroupKey == nil || self.cipheredGroupKey.length == 0) {
        NSLog(@"ERROR:No Group key for me yet");        
    }
    // get public key of receiver first
    RSA * rsa = [RSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRef];
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:self.cipheredGroupKey];
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
              @"encryptedGroupKey": @"cipheredGroupKeyString"
              };
}

@end

//public class TalkGroupMember {
//    public static final String ROLE_NONE = "none";
//    public static final String ROLE_ADMIN = "admin";
//    public static final String ROLE_MEMBER = "member";
//
//    private String groupId;
//    private String clientId;
//    private String role;
//    private String state;
//    private String invitationSecret;
//    private String encryptedGroupKey;
//    private Date lastChanged;
//}