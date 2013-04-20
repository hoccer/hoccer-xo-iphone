//
//  MessageCell.h
//  HoccerTalk
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class AutoheightLabel;
@class InsetImageView;
@class BubbleView;
@class TalkMessage;
@class MessageCell;


@protocol MessageViewControllerDelegate <NSObject>

- (void) presentAttachmentViewForCell: (MessageCell *) theCell;
- (BOOL) messageView:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender;
- (void) messageView:(MessageCell *)theCell saveMessage:(id)sender;
- (void) messageView:(MessageCell *)theCell forwardMessage:(id)sender;
- (void) messageView:(MessageCell *)theCell copy:(id)sender;
- (void) messageView:(MessageCell *)theCell deleteMessage:(id)sender;

@end

@interface MessageCell : HoccerTalkTableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet InsetImageView *avatar;
@property (strong, nonatomic) IBOutlet BubbleView *bubble;

@property (weak, nonatomic) id<MessageViewControllerDelegate> delegate;
@property (strong, nonatomic) NSIndexPath * indexPath;

- (CGFloat) heightForMessage: (TalkMessage*) message;

- (void)pressedButton: (id)sender;

@end


@interface LeftMessageCell : MessageCell
@end


@interface RightMessageCell : MessageCell
@end

@interface ChatTableSectionHeaderCell : HoccerTalkTableViewCell

@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UIImageView * backgroundImage;

@end

