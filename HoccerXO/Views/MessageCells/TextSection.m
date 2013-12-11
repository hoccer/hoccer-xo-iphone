//
//  TextSection.m
//  HoccerXO
//
//  Created by David Siegel on 11.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TextSection.h"
#import "HXOLinkyLabel.h"
#import "MessageCell.h"

// TODO: remove this
#import "HXOUserDefaults.h"

extern CGFloat kHXOGridSpacing;

@implementation TextSection

- (void) commonInit {
    [super commonInit];

    _label = [[HXOLinkyLabel alloc] initWithFrame: CGRectInset(self.bounds, 2 * kHXOGridSpacing, kHXOGridSpacing)];
    _label.numberOfLines = 0;
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label.backgroundColor = [UIColor clearColor];
    // TODO move font assignment to the view controller
    double fontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
    //    label.font = [UIFont systemFontOfSize: 13.0];
    _label.font = [UIFont systemFontOfSize: fontSize];
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview: _label];
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.width -= 4 * kHXOGridSpacing;
    size.height -= 2 * kHXOGridSpacing;

    CGSize result = [_label sizeThatFits: size];

    result.width = size.width + 4 * kHXOGridSpacing;
    result.height += 2 * kHXOGridSpacing;
    return result;
}

@end
