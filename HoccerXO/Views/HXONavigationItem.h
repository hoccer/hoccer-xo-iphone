//
//  HXONavigationItem.h
//  HoccerXO
//
//  Created by David Siegel on 18.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HXONavigationTitleView : UIView

@property (nonatomic,readonly) UILabel                 * titleLabel;
@property (nonatomic,readonly) UIImageView             * logo;
@property (nonatomic,readonly) UIActivityIndicatorView * activityIndicator;
@property (nonatomic,readonly) UIButton                * promptButton;

@end

@interface HXONavigationItem : UINavigationItem
{
    HXONavigationTitleView * _customTitleView;
}

@property (nonatomic,assign) BOOL showLogo;
@property (nonatomic,assign) BOOL flexibleLeftButton;
@property (nonatomic,assign) BOOL flexibleRightButton;


@end

