//
//  BubbleViewToo.h
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum HXOBubbleColorScheme {
    HXOBubbleColorSchemeWhite,
    HXOBubbleColorSchemeRed,
    HXOBubbleColorSchemeBlue,
    HXOBubbleColorSchemeEtched,
    HXOBubbleColorSchemeBlack
} HXOBubbleColorScheme;

typedef enum HXOBubbleDirections {
    HXOBubblePointingLeft,
    HXOBubblePointingRight
} HXOBubbleDirection;

@interface BubbleViewToo : UIView

@property (nonatomic,assign) HXOBubbleColorScheme colorScheme;
@property (nonatomic,assign) HXOBubbleColorScheme pointDirection;

@end
