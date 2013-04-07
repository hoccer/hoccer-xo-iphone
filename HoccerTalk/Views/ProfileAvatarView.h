//
//  ProfileAvatarView.h
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ProfileAvatarView : UIView

@property (nonatomic,strong) UIImage * image;

@property (nonatomic,strong) UIColor * gradientTopColor;
@property (nonatomic,strong) UIColor * gradientBottomColor;

@property (nonatomic,strong) UIColor * shadowColor;
@property (nonatomic,assign) CGFloat   shadowRadius;
@property (nonatomic,assign) CGSize    shadowOffset;
@end
