//
//  NickNameLabelWithStatus.h
//  HoccerXO
//
//  Created by David Siegel on 29.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NickNameLabelWithStatus : UIView

@property (nonatomic, assign) BOOL            isOnline;
@property (nonatomic, strong) NSString *      text;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, strong) UIFont *        font;
@property (nonatomic, strong) UIColor *       textColor;

@end
