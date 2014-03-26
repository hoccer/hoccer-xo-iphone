//
//  HXOLabel.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOLabel.h"

@implementation HXOLabel


- (CGSize) intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    size.height += 10;
    return size;
}


- (void) setBounds:(CGRect)bounds {
    [super setBounds: bounds];
    if (self.preferredMaxLayoutWidth != self.bounds.size.width) {
        self.preferredMaxLayoutWidth = self.bounds.size.width;
    }
}
@end
