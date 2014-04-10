//
//  HXOLabel.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOLabel.h"

@implementation HXOLabel

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.textInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    }
    return self;
}

- (CGSize) intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    size.width  += self.textInsets.left + self.textInsets.right;
    size.height += self.textInsets.top  + self.textInsets.bottom;
    return size;
}

/*
- (CGSize) sizeThatFits:(CGSize)size {
    size = [super sizeThatFits: size];
    size.width  += self.textInsets.left + self.textInsets.right;
    size.height += self.textInsets.top  + self.textInsets.bottom;
    return size;
}
*/
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.textInsets)];
}

@end
