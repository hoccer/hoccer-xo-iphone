//
//  BubbleView.h
//  HoccerXO
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AutoheightLabel;
@class HXOMessage;
@class AttachmentView;

typedef enum BubbleStates {
    BubbleStateInTransit,
    BubbleStateDelivered,
    BubbleStateFailed
} BubbleState;

@interface BubbleView : UIView

@property (nonatomic) UIEdgeInsets padding;
@property (strong, nonatomic) IBOutlet AutoheightLabel* message;
@property (strong, nonatomic) UIColor* bubbleColor;
@property (nonatomic) BOOL pointingRight;
@property (strong,nonatomic) AttachmentView * attachmentView;
@property (nonatomic,assign) BubbleState state;


- (id) initWithCoder:(NSCoder *)aDecoder;
- (void) awakeFromNib;

- (CGFloat) heightForMessage: (HXOMessage*) message;
- (CGRect) calcAttachmentViewFrameForAspect:(float)aspectRatio;

@end
