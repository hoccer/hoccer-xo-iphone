//
//  TextMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 10.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TextMessageCell.h"
#import "TextSection.h"

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    _textSection = [[TextSection alloc] initWithFrame:CGRectMake(0, self.gridSpacing, self.bubbleWidth, 5 * self.gridSpacing)];
    [self addSection: _textSection];
}

- (HXOLinkyLabel*) label {
    return _textSection.label;
}

- (void) layoutSubviews {
    [_textSection sizeToFit];
}
@end
