//
//  AudioAttachmentCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class Attachment;
@class AvatarView;

@interface AudioAttachmentCell : HXOTableViewCell

@property (nonatomic,readonly) UILabel     * titleLabel;
@property (nonatomic,readonly) UILabel     * subtitleLabel;
@property (nonatomic,readonly) UIImageView * artwork;
@property (nonatomic,strong)   Attachment  * attachment;

- (void) commonInit;
- (void) preferredContentSizeChanged: (NSNotification*) notification;

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views;

- (CGFloat) artworkSize;
- (CGFloat) verticalPadding;
- (CGFloat) labelSpacing;

@end
