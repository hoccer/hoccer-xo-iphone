//
//  GroupMemberCell.m
//  HoccerXO
//
//  Created by David Siegel on 22.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupMemberCell.h"

extern const CGFloat kHXOGridSpacing;

@implementation GroupMemberCell


- (void) awakeFromNib {
    [super awakeFromNib];
    self.editingAccessoryView = self.accessoryView;
    // TODO: customize selectedBackgroundView and re-enable highlighting in XIB
}

@end
