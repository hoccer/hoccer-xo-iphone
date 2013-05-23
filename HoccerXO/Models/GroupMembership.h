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
@property (nonatomic, retain) NSDate * lastChanged;
@property (nonatomic, retain) NSData * cipheredGroupKey;
@property (nonatomic, retain) NSData * distributedCipheredGroupKey;

@property (nonatomic, retain) NSDate * lastChangedMillis;
@property (nonatomic, retain) NSString * cipheredGroupKeyString;
@property (nonatomic, retain) NSString * distributedCipheredGroupKeyString;

- (NSData *) calcCipheredGroupKey;

@end
