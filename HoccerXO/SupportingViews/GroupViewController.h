//
//  GroupViewController.h
//  HoccerXO
//
//  Created by David Siegel on 17.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewController.h"

@class HXOBackend;
@class Group;
@class AvatarItem;

@interface GroupViewController : ProfileViewController <NSFetchedResultsControllerDelegate, UIActionSheetDelegate>

@property (nonatomic,strong) Group * group;
@property (nonatomic,readonly) HXOBackend * backend;

@end
