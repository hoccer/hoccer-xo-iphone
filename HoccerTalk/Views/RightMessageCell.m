//
//  RightMessageCell.m
//  Hoccenger
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "RightMessageCell.h"

#import "BubbleView.h"

@implementation RightMessageCell

- (void) awakeFromNib {
    self.bubble.pointingRight = YES;
}

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}
@end
