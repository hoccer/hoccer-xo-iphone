//
//  GroupMembership.h
//  QRCodeEncoderObjectiveCAtGithub
//
//  Created by David Siegel on 15.05.13.
//
//

#import <Foundation/Foundation.h>
#import "HXOModel.h"

@class Contact, Group;

@interface GroupMembership : HXOModel

@property (nonatomic, retain) NSString * role;
@property (nonatomic, retain) NSString * state;
@property (nonatomic, retain) Group *group;
@property (nonatomic, retain) Contact *contact;
@property (nonatomic, retain) Contact *ownGroupContact;
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSData * cipheredGroupKey;
@property (nonatomic, retain) NSData * distributedCipheredGroupKey;
@property (nonatomic, retain) NSData * distributedGroupKey;

@property (nonatomic, retain) NSDate * lastChangedMillis;
@property (nonatomic, retain) NSString * cipheredGroupKeyString;
@property (nonatomic, retain) NSString * distributedCipheredGroupKeyString;
@property (nonatomic, retain) NSString * memberKeyId;

@property (nonatomic, retain) NSData   * sharedKeyId;
@property (nonatomic, retain) NSData   * sharedKeyIdSalt;

@property (nonatomic, retain) NSString   * sharedKeyIdString;
@property (nonatomic, retain) NSString   * sharedKeyIdSaltString;

@property (nonatomic, retain) NSString * keySupplier;
@property (nonatomic, retain) NSDate * sharedKeyDate;
@property (nonatomic, retain) NSDate * sharedKeyDateMillis;

@property (nonatomic) BOOL keySettingInProgress;

- (NSData *) calcCipheredGroupKey;
- (NSData *) decryptedGroupKey;
- (BOOL) hasCipheredGroupKey;
- (BOOL) copyKeyFromGroup;
- (BOOL) hasLatestGroupKey;

-(void) checkGroupKey;
-(BOOL) checkGroupKeyTransfer:(NSString*)cipheredGroupKeyString withKeyId:(NSString*)keyIdString withSharedKeyId:(NSString*)sharedKeyIdString withSharedKeyIdSalt:(NSString*)sharedKeyIdSaltString;


@end
