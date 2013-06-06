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
    // TODO: customize selectedBAckgroundView and re-enable highlighting in XIB
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect frame = self.backgroundView.frame;
    CGFloat padding = frame.origin.x;
    frame.origin.x = 0;
    frame.size.width += 2 * padding;
    self.backgroundView.frame = frame;
    frame = self.contentView.frame;
    frame.origin.x = 0;
    frame.size.width += 2 * padding;
    self.contentView.frame = frame;
}

@end
