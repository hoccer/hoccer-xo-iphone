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

//- (void) presentAttachmentViewForCell: (MessageCell *) theCell;
- (BOOL) messageCell:(MessageCell *)cell canPerformAction:(SEL)action withSender:(id)sender;
- (void) messageCell:(MessageCell *)cell saveMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell copy:(id)sender;
- (void) messageCell:(MessageCell *)cell deleteMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell resendMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell forwardMessage:(id)sender;

- (void) messageCellDidPressAvatar:(MessageCell *)cell;
@end

typedef enum HXOMessageDirections {
    HXOMessageDirectionIncoming,
    HXOMessageDirectionOutgoing
} HXOMessageDirection;


@interface MessageCell : HXOTableViewCell

@property (weak, nonatomic) id<MessageViewControllerDelegate> delegate;

// TODO: clean up this mess
@property (weak, nonatomic) NSFetchedResultsController *      fetchedResultsController;

@property (nonatomic,readonly) UILabel *           subtitle;
@property (nonatomic,readonly) UIButton *          avatar;
@property (nonatomic,assign)   HXOMessageDirection messageDirection;

- (void) commonInit;

@end