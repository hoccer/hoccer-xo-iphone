//
//  BubbleViewToo.h
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "Attachment.h"
#import "MessageCell.h"

@class InsetImageView2;
@class HXOLinkyLabel;

typedef enum HXOAttachmentStyles {
    HXOAttachmentStyleThumbnail,
    HXOAttachmentStyleOriginalAspect,
    HXOAttachmentStyleCropped16To9
} HXOAttachmentStyle;


@interface BubbleViewToo : MessageCell


- (CGFloat) calculateHeightForWidth: (CGFloat) width;

@end

@interface CrappyTextMessageCell : BubbleViewToo

@property (nonatomic,readonly) HXOLinkyLabel * label;

@end

typedef enum HXOAttachmentTransferStates {
    HXOAttachmentTransferStateDone,
    HXOAttachmentTransferStateInProgress,
    HXOAttachmentTranserStateDownloadPending
} HXOAttachmentTranserState;

typedef enum HXOBubbleRunButtonStyles {
    HXOBubbleRunButtonNone,
    HXOBubbleRunButtonPlay
} HXOBubbleRunButtonStyle;

typedef enum HXOThumbnailScaleModes {
    HXOThumbnailScaleModeStretchToFit,
    HXOThumbnailScaleModeAspectFill,
    HXOThumbnailScaleModeActualSize
} HXOThumbnailScaleMode;

@interface CrappyAttachmentMessageCell : BubbleViewToo <TransferProgressIndication>

@property (nonatomic,readonly) UIProgressView *         progressBar;
@property (nonatomic,readonly) UILabel *                attachmentTitle;
@property (nonatomic,strong) UIImage *                  previewImage;
@property (nonatomic,assign) CGFloat                    imageAspect;
@property (nonatomic,assign) HXOAttachmentStyle         attachmentStyle;
@property (nonatomic,strong) UIImage *                  smallAttachmentTypeIcon;
@property (nonatomic,strong) UIImage *                  largeAttachmentTypeIcon;
@property (nonatomic,assign) HXOAttachmentTranserState  attachmentTransferState;
@property (nonatomic,assign) HXOBubbleRunButtonStyle    runButtonStyle;
@property (nonatomic,assign) HXOThumbnailScaleMode      thumbnailScaleMode;

@end

@interface CrappyAttachmentWithTextMessageCell : CrappyAttachmentMessageCell
{
    CGFloat _textPartHeight;
}

@property (nonatomic,readonly) HXOLinkyLabel * label;

- (CGFloat) calculateHeightForWidth: (CGFloat) width;

@end



