//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"

@implementation ContactCell

- (void) awakeFromNib {
    [super awakeFromNib];

    [self engraveLabel: self.nickName];
    self.nickName.textColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
    
    [self engraveLabel: self.statusLabel];
    self.statusLabel.textColor = [UIColor colorWithWhite: 0.5 alpha: 1.0];
    
    self.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"contact-settings"]];
}

- (NSString*) backgroundName {
    return @"contacts_and_groups_cell_bg";
}

@end
