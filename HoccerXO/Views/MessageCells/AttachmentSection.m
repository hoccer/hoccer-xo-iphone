//
//  AttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentSection.h"
#import "HXOUpDownLoadControl.h"
#import "MessageCell.h"

@implementation AttachmentSection

- (void) commonInit {
    [super commonInit];

    _subtitle = [[UILabel alloc] init];
    self.subtitle.textColor = self.tintColor;
    self.subtitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self addSubview: self.subtitle];

    _upDownLoadControl = [[HXOUpDownLoadControl alloc] initWithFrame: [self attachmentControlFrame]];
    self.upDownLoadControl.frame = [self attachmentControlFrame];
    [self addSubview: self.upDownLoadControl];
}

- (CGRect) attachmentControlFrame {
    return CGRectZero;
}

- (void) messageDirectionDidChange {
    [super messageDirectionDidChange];
    self.upDownLoadControl.transferDirection = self.cell.messageDirection == HXOMessageDirectionIncoming ? HXOTranserDirectionReceiving : HXOTranserDirectionSending;
}

@end
