//
//  CustomNavigationBar.h
//  HoccerXO
//
//  Created by David Siegel on 02.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CAShapeLayer;

@interface HXONavigationBar : UINavigationBar
{
    CAShapeLayer * _mask;
}
@end
