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

    self.nickName.textColor = [UIColor colorWithWhite: 0.2 alpha: 1.0];
}

@end
