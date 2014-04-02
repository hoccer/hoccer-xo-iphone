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
#import "HXOUI.h"
#import "HXOUI.h"

// TODO: remove this
#import "HXOUserDefaults.h"

@implementation TextSection

- (void) commonInit {
    [super commonInit];

    _label = [[HXOHyperLabel alloc] initWithFrame: CGRectInset(self.bounds, 2 * kHXOGridSpacing, kHXOGridSpacing)];
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _label.backgroundColor = [UIColor clearColor];
    // TODO move font assignment to the view controller
    _label.font = [HXOUI theme].messageFont;
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    [self addSubview: _label];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];

    [self preferredContentSizeChanged: nil];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (CGSize) sizeThatFits:(CGSize)size {
    CGSize labelSize = size;
    labelSize.width -= 4 * kHXOGridSpacing;
    //labelSize.height -= 2 * kHXOGridSpacing;
    labelSize.height = 0;

    labelSize = [_label sizeThatFits: labelSize];

    labelSize.width = size.width;
    labelSize.height = kHXOGridSpacing * ceil(labelSize.height / kHXOGridSpacing);
    labelSize.height += 2 * kHXOGridSpacing;
    labelSize.height = MAX(labelSize.height, 5 * kHXOGridSpacing);
    return labelSize;
}

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.label.textColor = [[HXOUI theme] messageTextColorForScheme: self.cell.colorScheme];
    self.label.linkColor = [[HXOUI theme] messageLinkColorForScheme: self.cell.colorScheme];
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    self.label.font = [[HXOUI theme] messageFont];
    [self setNeedsLayout];
}


@end
