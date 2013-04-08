//
//  ProfileAvatarView.h
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProfileAvatarView : UIControl

@property (nonatomic,strong) UIImage * image;

@property (nonatomic,strong) UIColor * gradientTopColor;
@property (nonatomic,strong) UIColor * gradientBottomColor;

@property (nonatomic,strong) UIColor * innerShadowColor;
@property (nonatomic,assign) CGFloat   innerShadowBlurRadius;
@property (nonatomic,assign) CGSize    innerShadowOffset;

@property (nonatomic,strong) UIColor * outerShadowColor;
@property (nonatomic,assign) CGFloat   outerShadowBlurRadius;
@property (nonatomic,assign) CGSize    outerShadowOffset;

@end
