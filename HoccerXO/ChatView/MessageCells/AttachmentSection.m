//
//  AttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentSection.h"
#import "UpDownLoadControl.h"
#import "MessageCell.h"
#import "HXOUI.h"

@implementation AttachmentSection

- (void) commonInit {
    [super commonInit];

    _subtitle = [[UILabel alloc] init];
    self.subtitle.textColor = self.tintColor;
    self.subtitle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self addSubview: self.subtitle];

    _upDownLoadControl = [[UpDownLoadControl alloc] initWithFrame: [self attachmentControlFrame]];
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

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.subtitle.textColor = [[HXOUI theme] messageAttachmentSubtitleColorForScheme: self.cell.colorScheme];
    self.upDownLoadControl.tintColor = [[HXOUI theme] messageAttachmentIconTintColorForScheme: self.cell.colorScheme];
}

@end
