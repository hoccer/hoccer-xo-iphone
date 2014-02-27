//
//  TextSection.m
//  HoccerXO
//
//  Created by David Siegel on 11.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TextSection.h"
#import "HXOHyperLabel.h"
#import "MessageCell.h"
#import "HXOTheme.h"

// TODO: remove this
#import "HXOUserDefaults.h"

extern CGFloat kHXOGridSpacing;

@implementation TextSection

- (void) commonInit {
    [super commonInit];

    _label = [[HXOHyperLabel alloc] initWithFrame: CGRectInset(self.bounds, 2 * kHXOGridSpacing, kHXOGridSpacing)];
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
    CGSize labelSize = size;
    labelSize.width -= 4 * kHXOGridSpacing;
    labelSize.height -= 2 * kHXOGridSpacing;

    labelSize = [_label sizeThatFits: labelSize];

    labelSize.width = size.width;
    labelSize.height = kHXOGridSpacing * ceil(labelSize.height / kHXOGridSpacing);
    labelSize.height += 2 * kHXOGridSpacing;
    labelSize.height = MAX(labelSize.height, 5 * kHXOGridSpacing);
    return labelSize;
}

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.label.textColor = [[HXOTheme theme] messageTextColorForScheme: self.cell.colorScheme];
    self.label.linkColor = [[HXOTheme theme] messageLinkColorForScheme: self.cell.colorScheme];
}

@end
