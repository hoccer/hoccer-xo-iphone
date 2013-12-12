//
//  AttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentSection.h"

@implementation AttachmentSection


- (void) commonInit {
    [super commonInit];

    _subtitle = [[UILabel alloc] init];
    _subtitle.textColor = [UIColor blueColor];
    [self addSubview: self.subtitle];

    
}

@end
