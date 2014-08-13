//
//  ContactCellProtocol.h
//  HoccerXO
//
//  Created by David Siegel on 10.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AvatarView;
@protocol ContactCellDelegate;

@protocol ContactCell <NSObject>

@property (nonatomic, readonly) AvatarView * avatar;
@property (nonatomic, readonly) UILabel    * titleLabel;
@property (nonatomic, readonly) UILabel    * subtitleLabel;
@property (nonatomic, weak)    id<ContactCellDelegate>   delegate;

- (void) preferredContentSizeChanged: (NSNotification*) notification;

@end
