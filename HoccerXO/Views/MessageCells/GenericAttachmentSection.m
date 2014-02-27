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
#import "HXOTheme.h"

extern CGFloat kHXOGridSpacing;

@implementation GenericAttachmentSection

- (void) commonInit {
    [super commonInit];

    _title = [[UILabel alloc] initWithFrame:CGRectMake(2 * kHXOGridSpacing, 0, self.bounds.size.width - 9 * kHXOGridSpacing, 32)];
    self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview: self.title];

    self.upDownLoadControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

    _icon = [[UIImageView alloc] initWithFrame: [self attachmentControlFrame]];
    self.icon.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview: self.icon];

    self.subtitle.frame = CGRectMake(2 * kHXOGridSpacing, 24, self.bounds.size.width - 9 * kHXOGridSpacing, 16);
    self.subtitle.font = [UIFont systemFontOfSize: 10];

}

- (CGSize) sizeThatFits:(CGSize)size {
    size.height = 6 * kHXOGridSpacing;
    return size;
}

- (void) colorSchemeDidChange {
    [super colorSchemeDidChange];
    self.title.textColor = [[HXOTheme theme] messageAttachmentTitleColorForScheme: self.cell.colorScheme];
    self.subtitle.textColor = [[HXOTheme theme] messageAttachmentSubtitleColorForScheme: self.cell.colorScheme];
    self.icon.tintColor = [[HXOTheme theme] messageAttachmentIconTintColorForScheme: self.cell.colorScheme];
}

- (CGRect) attachmentControlFrame {
    return CGRectMake(self.bounds.size.width - (2 * kHXOGridSpacing + 4 * kHXOGridSpacing), kHXOGridSpacing, 4 * kHXOGridSpacing, 4 * kHXOGridSpacing);
}



@end
