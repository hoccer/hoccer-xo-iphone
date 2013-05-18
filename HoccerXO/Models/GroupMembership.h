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

@end
