//
//  RadialGradientView.h
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RadialGradientView : UIView

+ (void) drawInContext: (CGContextRef) context withSize: (CGSize) size andCenter: (CGPoint) center;

@end
