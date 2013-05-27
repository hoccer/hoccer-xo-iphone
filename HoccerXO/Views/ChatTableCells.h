//
//  MessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class AutoheightLabel;
@class InsetImageView;
@class BubbleView;
@class HXOMessage;
@class MessageCell;


@protocol MessageViewControllerDelegate <NSObject>

- (void) presentAttachmentViewForCell: (MessageCell *) theCell;
- (BOOL) messageView:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender;
- (void) messageView:(MessageCell *)theCell saveMessage:(id)sender;
- (void) messageView:(MessageCell *)theCell copy:(id)sender;
- (void) messageView:(MessageCell *)theCell deleteMessage:(id)sender;
- (void) messageView:(MessageCell *)theCell resendMessage:(id)sender;
- (void) messageView:(MessageCell *)theCell forwardMessage:(id)sender;

@end

@interface MessageCell : HXOTableViewCell

@property (weak, nonatomic) id<MessageViewControllerDelegate> delegate;
@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet InsetImageView *avatar;
@property (strong, nonatomic) IBOutlet BubbleView *bubble;
@property (strong, nonatomic) IBOutlet UILabel *nickNameLabel;


// @property UIInterfaceOrientation cellOrientation;

- (CGFloat) heightForMessage: (HXOMessage*) message;

- (void)pressedButton: (id)sender;

@end


@interface LeftMessageCell : MessageCell
@end


@interface RightMessageCell : MessageCell
@end

@interface ChatTableSectionHeaderCell : HXOTableViewCell <UIGestureRecognizerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UIImageView * backgroundImage;

@end

