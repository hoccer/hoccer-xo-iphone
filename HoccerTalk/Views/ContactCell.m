//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

@interface ContactCell ()

@property (nonatomic, strong) UIImageView * messageCountBackground;
@property (nonatomic,strong) IBOutlet UILabel * messageCountLabel;

@end

@implementation ContactCell

@synthesize hasUnreadMessages = _hasUnreadMessages;

static const double kMessageCountBackgroundHPadding = 9;
static const double kMessageCountBackgroundVPadding = 2;
static const double kMessageCountBackgroundVOffset = 0.5;
static const double kMessageCountBackgroundMinWidth = 25;
+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.messageCountLabel.backgroundColor = [UIColor clearColor];
    self.messageCountLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.messageCountLabel.layer.shadowOffset = CGSizeMake(0.0, -1.0);
    self.messageCountLabel.layer.shadowOpacity = 1.0;
    self.messageCountLabel.layer.shadowRadius = 0.0;
    self.messageCountBackground = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight:10]];
    self.messageCountBackground.frame = self.messageCountLabel.frame;
    [self addSubview: self.messageCountBackground];
    [self sendSubviewToBack: self.messageCountBackground];
    self.messageCountBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
}

- (BOOL) hasUnreadMessages {
    return _hasUnreadMessages;
}

- (void) setHasUnreadMessages:(BOOL)hasUnreadMessages {
    _hasUnreadMessages = hasUnreadMessages;
    self.messageCountBackground.image = [AssetStore stretchableImageNamed: hasUnreadMessages ? @"bg_message-count-red" : @"bg_message-count-grey" withLeftCapWidth: 10 topCapHeight: 10];
    self.messageCountLabel.textColor = hasUnreadMessages ? [UIColor whiteColor] : [UIColor colorWithWhite: 0.8 alpha: 1.0];
}

- (NSInteger) messageCount {
    return self.messageCountLabel.text.integerValue;
}

- (void) setMessageCount: (NSInteger) count {
    self.messageCountLabel.text = [NSNumber numberWithInteger: count].stringValue;
    double oldWidth = self.messageCountLabel.frame.size.width;
    [self.messageCountLabel sizeToFit];

    // right align labels
    CGRect frame = self.messageCountLabel.frame;
    self.messageCountLabel.frame = CGRectMake(frame.origin.x + (oldWidth - frame.size.width), frame.origin.y, frame.size.width, frame.size.height);

    self.messageCountBackground.frame = CGRectMake(self.messageCountLabel.frame.origin.x - kMessageCountBackgroundHPadding, self.messageCountLabel.frame.origin.y + kMessageCountBackgroundVOffset - kMessageCountBackgroundVPadding, MAX(self.messageCountLabel.frame.size.width + 2 * kMessageCountBackgroundHPadding, kMessageCountBackgroundMinWidth), self.messageCountLabel.frame.size.height + 2 * kMessageCountBackgroundVPadding);
}


@end
