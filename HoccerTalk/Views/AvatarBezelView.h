//
//  AvatarView.h
//  HoccerTalk
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AvatarBezelView : UIControl

@property (strong, nonatomic) UIImage *image;

@property (assign, nonatomic) double    cornerRadius;
@property (strong, nonatomic) UIColor * bezelColor;
@property (strong, nonatomic) UIColor * innerShadowColor;
@property (strong, nonatomic) UIColor * insetColor;

@end
