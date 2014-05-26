//
//  player_button_next.m
//  HoccerXO
//
//  Created by Peter Amende on 22.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "player_icon_now_playing.h"

@implementation player_icon_now_playing

- (void)initPath {

    //// Rectangle Drawing
    self.path = [UIBezierPath bezierPathWithRect: CGRectMake(1, 7, 3, 5)];
    [self.path appendPath:[UIBezierPath bezierPathWithRect: CGRectMake(6, 3, 3, 9)]];
    [self.path appendPath:[UIBezierPath bezierPathWithRect: CGRectMake(11, 9, 3, 3)]];
    
    self.fillColor = [[HXOUI theme] cellAccessoryColor];;
}

@end
