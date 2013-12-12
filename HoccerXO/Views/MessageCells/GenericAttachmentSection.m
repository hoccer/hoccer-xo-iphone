//
//  GenericAttachmentSection.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GenericAttachmentSection.h"
#import "MessageCell.h"

extern CGFloat kHXOGridSpacing;


@implementation GenericAttachmentSection

- (void) commonInit {
    [super commonInit];

    _title = [[UILabel alloc] initWithFrame:CGRectMake(2 * kHXOGridSpacing, 0, self.bounds.size.width - 9 * kHXOGridSpacing, 32)];
    self.title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.title.backgroundColor = [UIColor orangeColor];
    [self addSubview: self.title];

    // TODO: assign subtitle frame
    
}

- (CGSize) sizeThatFits:(CGSize)size {
    size.height = 6 * kHXOGridSpacing;
    return size;
}

- (void) colorSchemeDidChange {
    self.title.textColor = [self.cell textColor];
}
@end
