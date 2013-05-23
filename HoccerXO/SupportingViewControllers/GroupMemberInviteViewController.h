//
//  InviteGroupMemberViewController.h
//  HoccerXO
//
//  Created by David Siegel on 22.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"
#import "Group.h"

@interface GroupMemberInviteViewController : ContactListViewController <UIAlertViewDelegate>

@property (nonatomic,strong) Group * group;

@end
