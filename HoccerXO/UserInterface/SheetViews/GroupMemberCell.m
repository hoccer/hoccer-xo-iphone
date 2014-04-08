//
//  GroupMemberCell.m
//  HoccerXO
//
//  Created by David Siegel on 08.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GroupMemberCell.h"

#import "HXOUI.h"

@implementation GroupMemberCell

- (CGFloat) avatarSize {
    return 4.5 * kHXOGridSpacing; // ehem...
}

- (CGFloat) verticalPadding {
    return kHXOGridSpacing;
}

@end
