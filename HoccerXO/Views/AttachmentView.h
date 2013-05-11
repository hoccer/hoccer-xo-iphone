//
//  AttachmentView.h
//  HoccerXO
//
//  Created by Pavel on 15.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Attachment.h"

@class MessageCell;

@interface AttachmentView : UIView <TransferProgressIndication>

@property (strong,nonatomic) UIImageView * imageView;
@property (strong,nonatomic) UIButton * loadButton;
@property (strong,nonatomic) UIButton * openButton;
@property (strong,nonatomic) UIProgressView * progressView;
@property (strong,nonatomic) UILabel * nameLabel;

@property (weak,nonatomic) Attachment * attachment;
@property (weak,nonatomic) MessageCell * cell;

@property float aspect;

- (void) configureViewForAttachment: (Attachment*) theAttachment inCell:(MessageCell*) cell;

@end
