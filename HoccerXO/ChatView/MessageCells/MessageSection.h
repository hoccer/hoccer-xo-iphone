//
//  MessageSection.h
//  HoccerXO
//
//  Created by David Siegel on 11.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#define MESSAGE_CELL_USE_LAYERS

@class MessageCell;

typedef enum HXOMessageDirections {
    HXOMessageDirectionIncoming,
    HXOMessageDirectionOutgoing
} HXOMessageDirection;

typedef enum HXOBubbleColorSchemes {
    HXOBubbleColorSchemeIncoming,
    HXOBubbleColorSchemeFailed,
    HXOBubbleColorSchemeSuccess,
    HXOBubbleColorSchemeInProgress
} HXOBubbleColorScheme;

typedef enum HXOSectionPositions {
    HXOSectionPositionSingle,
    HXOSectionPositionFirst,
    HXOSectionPositionInner,
    HXOSectionPositionLast
} HXOSSectionPosition;

@interface MessageSection : UIView

@property (nonatomic,weak) MessageCell * cell;
@property (nonatomic,assign) HXOSSectionPosition position;

- (void) commonInit;
- (void) colorSchemeDidChange;
- (void) messageDirectionDidChange;
- (UIBezierPath*) bubblePath;

#ifdef MESSAGE_CELL_USE_LAYERS
@property (nonatomic,readonly) CAShapeLayer* bubbleLayer;
#endif

@end
