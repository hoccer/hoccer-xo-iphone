//
//  BubbleViewToo.h
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class InsetImageView;
@class HXOLinkyLabel;

typedef enum HXOAttachmentStyles {
    HXOAttachmentStyleThumbnail,
    HXOAttachmentStyleOriginalAspect,
    HXOAttachmentStyleCropped16To9
} HXOAttachmentStyle;

typedef enum HXOBubbleColorSchemes {
    HXOBubbleColorSchemeWhite,
    HXOBubbleColorSchemeRed,
    HXOBubbleColorSchemeBlue,
    HXOBubbleColorSchemeEtched
} HXOBubbleColorScheme;

typedef enum HXOMessageDirections {
    HXOMessageDirectionIncoming,
    HXOMessageDirectionOutgoing
} HXOMessageDirection;

@interface BubbleViewToo : HXOTableViewCell

@property (nonatomic,assign) HXOBubbleColorScheme    colorScheme;
@property (nonatomic,assign) HXOMessageDirection     messageDirection;
@property (nonatomic,readonly) InsetImageView *      avatar;

- (CGFloat) calculateHeightForWidth: (CGFloat) width;

@end

@interface TextMessageCell : BubbleViewToo

@property (nonatomic,readonly) HXOLinkyLabel * label;

@end

typedef enum HXOAttachmentTransferStates {
    HXOAttachmentTransferStateDone,
    HXOAttachmentTranserStateInProgress
} HXOAttachmentTranserState;

typedef enum HXOBubbleRunButtonStyles {
    HXOBubbleRunButtonNone,
    HXOBubbleRunButtonPlay
} HXOBubbleRunButtonStyle;

@interface AttachmentMessageCell : BubbleViewToo

@property (nonatomic,readonly) UIProgressView *         progressBar;
@property (nonatomic,readonly) UILabel *                attachmentTitle;
@property (nonatomic,strong) UIImage *                  previewImage;
@property (nonatomic,assign) CGFloat                    imageAspect;
@property (nonatomic,assign) HXOAttachmentStyle         attachmentStyle;
@property (nonatomic,strong) UIImage *                  smallAttachmentTypeIcon;
@property (nonatomic,strong) UIImage *                  largeAttachmentTypeIcon;
@property (nonatomic,assign) HXOAttachmentTranserState  attachmentTransferState;
@property (nonatomic,assign) HXOBubbleRunButtonStyle    runButtonStyle;

@end

@interface AttachmentWithTextMessageCell : AttachmentMessageCell
{
    CGFloat _textPartHeight;
}

- (CGFloat) calculateHeightForWidth: (CGFloat) width;

@end



