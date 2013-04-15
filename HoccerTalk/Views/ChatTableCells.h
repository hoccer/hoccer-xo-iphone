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


@protocol AttachmentViewControllerDelegate <NSObject>

- (void) presentAttachmentViewForCell: (MessageCell *) theCell;

@end

@interface MessageCell : HoccerTalkTableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet InsetImageView *avatar;
@property (strong, nonatomic) IBOutlet BubbleView *bubble;

@property (weak, nonatomic) id<AttachmentViewControllerDelegate> delegate;
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

