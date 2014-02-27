//
//  MessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "MessageSection.h"
#import "HXOAvatarButton.h"

@class MessageCell;
@class AttachmentSection;

@protocol AttachmentMessageCell <NSObject>

@property (nonatomic,readonly) AttachmentSection* attachmentSection;

@end


@protocol MessageViewControllerDelegate <NSObject>

- (BOOL) messageCell:(MessageCell *)cell canPerformAction:(SEL)action withSender:(id)sender;
- (void) messageCell:(MessageCell *)cell saveMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell copy:(id)sender;
- (void) messageCell:(MessageCell *)cell deleteMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell resendMessage:(id)sender;
//- (void) messageCell:(MessageCell *)cell forwardMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell openWithMessage:(id)sender;
- (void) messageCell:(MessageCell *)cell shareMessage:(id)sender;
- (void) messageCellDidPressAvatar:(MessageCell *)cell;
@end

@interface MessageCell : HXOTableViewCell
@property (weak, nonatomic) id<MessageViewControllerDelegate> delegate;

@property (nonatomic,readonly) UILabel *             subtitle;
@property (nonatomic,readonly) HXOAvatarButton *     avatar;
@property (nonatomic,assign)   HXOMessageDirection   messageDirection;
@property (nonatomic,readonly) NSMutableArray *      sections;
@property (nonatomic,assign)   HXOBubbleColorScheme  colorScheme;
@property (nonatomic,readonly) CGFloat               bubbleWidth;


- (void) commonInit;
- (void) addSection: (MessageSection*) section;
@end