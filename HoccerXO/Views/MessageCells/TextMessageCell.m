//
//  TextMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 10.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TextMessageCell.h"
#import "TextSection.h"

@interface TextMessageCell ()

@property (nonatomic,strong) TextSection * textSection;

@end

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    self.textSection = [[TextSection alloc] initWithFrame:CGRectMake(0, self.gridSpacing, self.bubbleWidth, 5 * self.gridSpacing)];
    [self addSection: _textSection];
}

- (HXOLinkyLabel*) label {
    return self.textSection.label;
}

- (void) layoutSubviews {
    [self.textSection sizeToFit];
}

@end
