//
//  LeftMessageCell.m
//  HoccerTalk
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "LeftMessageCell.h"

#import "BubbleView.h"

@implementation LeftMessageCell

- (void) awakeFromNib {
    self.bubble.pointingRight = NO;
}

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}
@end
