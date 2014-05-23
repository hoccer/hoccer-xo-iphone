//
//  ProfileAvatarView.h
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VectorArt;

@interface AvatarView : UIControl

@property (nonatomic, strong) UIImage   * image;
@property (nonatomic, strong) VectorArt * defaultIcon;
@property (nonatomic, assign) BOOL        isBlocked;
@property (nonatomic, assign) BOOL        isPresent;
@property (nonatomic, strong) NSString  * badgeText;
@property (nonatomic, strong) UIFont    * badgeFont;

@end
