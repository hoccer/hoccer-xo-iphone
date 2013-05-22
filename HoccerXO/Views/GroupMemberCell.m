//
//  GroupMemberCell.m
//  HoccerXO
//
//  Created by David Siegel on 22.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupMemberCell.h"

@implementation GroupMemberCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount {
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.editingAccessoryView = self.accessoryView;
}
@end
