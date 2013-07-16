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

typedef enum HXOBubbleAttachmentTypes {
    HXOBubbleAttachmentTypeNone,
    HXOBubbleAttachmentTypeIconic,
    HXOBubbleAttachmentTypeImage
} HXOBubbleAttachmentType;

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
//@property (nonatomic,assign) HXOBubbleAttachmentType attachmentType;
@property (nonatomic,readonly) InsetImageView *      avatar;

- (CGFloat) calculateHeightForWidth: (CGFloat) width;

@end

@interface TextMessageCell : BubbleViewToo

@property (nonatomic,readonly) HXOLinkyLabel * label;

@end

@interface AttachmentMessageCell : BubbleViewToo

@property (nonatomic,readonly) UIProgressView * progressBar;

@end



