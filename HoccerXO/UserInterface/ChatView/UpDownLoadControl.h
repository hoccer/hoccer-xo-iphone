//
//  HXOProgressControl.h
//  HoccerXO
//
//  Created by David Siegel on 14.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UpDownLoadControl : UIControl

typedef enum HXOTransferDirections {
    HXOTranserDirectionSending,
    HXOTranserDirectionReceiving
} HXOTranserDirection;

@property (nonatomic,assign) CGFloat             progress;
@property (nonatomic,assign) HXOTranserDirection transferDirection;
@property (nonatomic,assign) CGFloat             lineWidth;

- (void) startSpinning;

@end
