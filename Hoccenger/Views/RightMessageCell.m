//
//  RightMessageCell.m
//  Hoccenger
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "RightMessageCell.h"

@implementation RightMessageCell

- (void) awakeFromNib {
    [super awakeFromNib];
    self.message.arrowLeft = NO;
    self.message.bubbleColor = [UIColor colorWithRed: 242.0 / 255
                                               green: 242.0 / 255
                                                blue: 242.0 / 255
                                               alpha: 1];
}

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}
@end
