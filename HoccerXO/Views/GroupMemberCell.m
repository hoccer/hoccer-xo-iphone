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

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self) {
        CGRect frame = self.frame;
        frame.size.height = 7 * kHXOGridSpacing;
        self.frame = frame;

        self.avatar = [[UIImageView alloc] initWithFrame: CGRectMake( 2 * kHXOGridSpacing, 1 * kHXOGridSpacing, 5 * kHXOGridSpacing, 5 * kHXOGridSpacing)];
        self.avatar.layer.cornerRadius = 1 * kHXOGridSpacing;
        self.avatar.layer.masksToBounds = YES;
        [self.contentView addSubview: self.avatar];

        CGFloat x = CGRectGetMaxX(self.avatar.frame) + kHXOGridSpacing;
        self.nickName = [[NickNameLabelWithStatus alloc] initWithFrame: CGRectMake(x, kHXOGridSpacing, self.bounds.size.width - x, 3 * kHXOGridSpacing)];
        self.nickName.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
        [self.contentView addSubview: self.nickName];

        self.statusLabel = [[UILabel alloc] initWithFrame: CGRectMake(x, 4 * kHXOGridSpacing, self.bounds.size.width - x, 2 * kHXOGridSpacing)];
        self.statusLabel.font = [UIFont systemFontOfSize: 12];
        self.statusLabel.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
        [self.contentView addSubview: self.statusLabel];

    }
    return self;
}


- (void) awakeFromNib {
    [super awakeFromNib];
    self.editingAccessoryView = self.accessoryView;
    // TODO: customize selectedBackgroundView and re-enable highlighting in XIB
}

@end
