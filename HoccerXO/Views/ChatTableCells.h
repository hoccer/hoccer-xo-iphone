//
//  MessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class MessageCell;

@protocol MessageViewControllerDelegate <NSObject>

- (void) presentAttachmentViewForCell: (MessageCell *) theCell;
- (BOOL) messageCell:(MessageCell *)cell canPerformAction:(SEL)action withSender:(id)sender;
- (void) messageCell:(MessageCell *)cell saveMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell copy:(id)sender;
- (void) messageCell:(MessageCell *)cell deleteMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell resendMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell forwardMessage:(id)sender;

- (void) messageCellDidPressAvatar:(MessageCell *)cell;
@end

@interface MessageCell : HXOTableViewCell

@property (weak, nonatomic) id<MessageViewControllerDelegate> delegate;

@end

/*
@interface ChatTableSectionHeaderCell : HXOTableViewCell <UIGestureRecognizerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UIImageView * backgroundImage;

@end
 
 */

