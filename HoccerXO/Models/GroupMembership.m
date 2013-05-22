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


@implementation GroupMembership

@dynamic role;
@dynamic state;
@dynamic group;
@dynamic contact;
@dynamic lastChanged;

@dynamic lastChangedMillis;

- (NSNumber*) lastChangedMillis {
    return [HXOBackend millisFromDate:self.lastChanged];
}

- (void) setLastChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.lastChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}

- (NSDictionary*) rpcKeys {
    return @{ @"role"         : @"role",
              @"state"        : @"state",
              @"lastChanged"  : @"lastChangedMillis"
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