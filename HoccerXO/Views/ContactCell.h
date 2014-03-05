//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "HXOAvatarButton.h"
#import "LabelWithLED.h"
#import "HXOLabel.h"

FOUNDATION_EXPORT const CGFloat kPadding;
FOUNDATION_EXPORT const CGFloat kMaxImageSize;

@interface ContactCell : HXOTableViewCell

@property (nonatomic,readonly) LabelWithLED * nickName;
@property (nonatomic,readonly) HXOLabel * subtitleLabel;
@property (nonatomic,readonly) HXOAvatarButton   * avatar;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views;


@end
