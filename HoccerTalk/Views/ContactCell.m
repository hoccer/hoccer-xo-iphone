//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"

#import "AssetStore.h"

@interface ContactCell ()

@property (nonatomic, strong) UIImageView * messageCountBackground;
@property (nonatomic,strong) IBOutlet UILabel * messageCountLabel;

@end

@implementation ContactCell

@synthesize hasUnreadMessages = _hasUnreadMessages;

static const NSInteger kMessageCountBackgroundHPadding = 8;
static const NSInteger kMessageCountBackgroundVOffset = 1;

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.messageCountLabel.backgroundColor = [UIColor clearColor];
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
}

- (NSInteger) messageCount {
    return self.messageCountLabel.text.integerValue;
}

- (void) setMessageCount: (NSInteger) count {
    self.messageCountLabel.text = [NSNumber numberWithInteger: count].stringValue;
    [self.messageCountLabel sizeToFit];
    self.messageCountBackground.frame = CGRectMake(self.messageCountLabel.frame.origin.x - kMessageCountBackgroundHPadding, self.messageCountLabel.frame.origin.y + kMessageCountBackgroundVOffset, self.messageCountLabel.frame.size.width + 2 * kMessageCountBackgroundHPadding, self.messageCountLabel.frame.size.height);
}


@end
