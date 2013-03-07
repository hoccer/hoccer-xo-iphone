//
//  MessageCell.m
//  HoccerTalk
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"
#import "AutoheightLabel.h"
#import "BubbleView.h"

@implementation MessageCell

static const double kCellPadding = 10.0;

- (void) awakeFromNib {
    [super awakeFromNib];
}

- (float) heightForText: (NSString*) text {
    return MAX(kCellPadding + [self.bubble heightForText: text] + kCellPadding,
               self.frame.size.height);
}

@end
