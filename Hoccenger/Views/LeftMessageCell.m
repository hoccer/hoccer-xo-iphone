//
//  LeftMessageCell.m
//  Hoccenger
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "LeftMessageCell.h"

@implementation LeftMessageCell

- (void) awakeFromNib {
    [super awakeFromNib];
    self.message.arrowLeft = YES;
    self.message.bubbleColor = [UIColor colorWithRed: 220.0 / 255
                                               green: 236.0 / 255
                                                blue: 253.0 / 255
                                               alpha: 1];
}

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}
@end
