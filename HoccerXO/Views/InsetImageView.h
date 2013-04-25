//
//  AvatarView.h
//  HoccerXO
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InsetImageView : UIControl

@property (strong, nonatomic) UIImage *image;

@property (assign, nonatomic) double    cornerRadius;
@property (strong, nonatomic) UIColor * borderColor;
@property (strong, nonatomic) UIColor * insetColor;
@property (strong, nonatomic) UIColor * shadowColor;
@property (assign, nonatomic) double    shadowBlurRadius;
@property (assign, nonatomic) CGSize    shadowOffset;

@end
