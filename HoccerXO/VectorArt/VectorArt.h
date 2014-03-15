//
//  VectorArt.h
//  HoccerXO
//
//  Created by David Siegel on 15.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HXOTheme.h"

@interface VectorArt : NSObject

@property (nonatomic,strong) UIBezierPath * path;
@property (nonatomic,strong) UIColor *      strokeColor;
@property (nonatomic,strong) UIColor *      fillColor;

- (void) initPath;
- (UIImage*) image;

@end
