//
//  TextMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 10.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TextMessageCell.h"

#import "TextSection.h"
#import "HXOLayout.h"

@interface TextMessageCell ()

@end

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    [self addSection: [[TextSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 5 * kHXOGridSpacing)]];
}

@end
