//
//  GenericAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GenericAttachmentSection.h"
#import "MessageCell.h"
#import "HXOUpDownLoadControl.h"

extern CGFloat kHXOGridSpacing;

@implementation GenericAttachmentSection

- (void) commonInit {
    [super commonInit];

    _title = [[UILabel alloc] initWithFrame:CGRectMake(2 * kHXOGridSpacing, 0, self.bounds.size.width - 9 * kHXOGridSpacing, 32)];
    self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview: self.title];

    self.upDownLoadControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

    // TODO: assign subtitle frame

}

- (CGSize) sizeThatFits:(CGSize)size {
    size.height = 6 * kHXOGridSpacing;
    return size;
}

- (void) colorSchemeDidChange {
    self.title.textColor = [self.cell textColor];
}

- (CGRect) attachmentControlFrame {
    return CGRectMake(self.bounds.size.width - (2 * kHXOGridSpacing + 4 * kHXOGridSpacing), kHXOGridSpacing, 4 * kHXOGridSpacing, 4 * kHXOGridSpacing);
}



@end
