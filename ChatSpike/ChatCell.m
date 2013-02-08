//
//  ChatTableViewCell.m
//  ChatSpike
//
//  Created by David Siegel on 05.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "ChatCell.h"
#import "AutoheightLabel.h"

@interface ChatCell ()
{
    IBOutlet AutoheightLabel* incomingMessage;
    IBOutlet UIImageView* incomingAvatar;
    IBOutlet UILabel * incomingNick;

    IBOutlet AutoheightLabel* outgoingMessage;
    IBOutlet UIImageView* outgoingAvatar;
    IBOutlet UILabel * outgoingNick;
}

- (float) heightForText: (NSString*) text;

@end

@implementation ChatCell

- (void) configureView {
    incomingAvatar.layer.cornerRadius = 5;
    incomingAvatar.layer.masksToBounds = YES;
    incomingAvatar.layer.borderColor = [UIColor darkGrayColor].CGColor;
    incomingAvatar.layer.borderWidth = 1.5;

    outgoingAvatar.layer.cornerRadius = 5;
    outgoingAvatar.layer.masksToBounds = YES;
    outgoingAvatar.layer.borderColor = [UIColor darkGrayColor].CGColor;
    outgoingAvatar.layer.borderWidth = 1.5;
}

- (NSString*) messageText {
    return isIncoming ? incomingMessage.text : outgoingMessage.text;
}

- (void) setMessageText: (NSString*) text {
    if (isIncoming) {
        incomingMessage.text = text;
    } else {
        outgoingMessage.text = text;
    }
}
- (UIImage*) avatar {
    return isIncoming ? incomingAvatar.image : outgoingAvatar.image;
}

- (void) setAvatar: (UIImage*) image {
    if (isIncoming) {
        incomingAvatar.image = image;
    } else {
        outgoingAvatar.image = image;
    }
}

- (NSString*) nickName {
    return isIncoming ? incomingNick.text : outgoingNick.text;
}

- (void) setNickName: (NSString*) nick {
    if (isIncoming) {
        incomingNick.text = nick;
    } else {
        outgoingNick.text = nick;
    }
}

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (NSString *)reuseIdentifier
{
    return [[self class] reuseIdentifier];
}

+ (ChatCell *)cell
{
    ChatCell * cell = [[[NSBundle mainBundle] loadNibNamed:[self reuseIdentifier] owner:self options:nil] objectAtIndex:0];
    [cell configureView];
    return cell;
}

+ (float) heightForText: (NSString*) text {
    return [[ChatCell prototype] heightForText: text];
}

- (float) heightForText: (NSString*) text {
    return MAX(10 + [incomingMessage calculateSize: text].height + 10, self.frame.size.height);
}

+ (ChatCell*) prototype {
    static ChatCell * p;
    if ( ! p) p = [ChatCell cell];
    return p;
}

- (void) layout: (BOOL) isIncomingFlag {
    isIncoming = isIncomingFlag;
    incomingMessage.hidden = ! isIncoming;
    incomingAvatar.hidden  = ! isIncoming;
    incomingNick.hidden    = ! isIncoming;

    outgoingMessage.hidden =   isIncoming;
    outgoingAvatar.hidden  =   isIncoming;
    outgoingNick.hidden    =   isIncoming;
}

@end
