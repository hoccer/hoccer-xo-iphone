//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class InsetImageView;
@class NickNameLabelWithStatus;

@interface ContactQuickListCell : HXOTableViewCell

@property (nonatomic,strong) IBOutlet NickNameLabelWithStatus * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView * avatar;

- (void) setMessageCount: (NSInteger) count isUnread: (BOOL) unreadFlag;

@end

@interface ContactQuickListSectionHeaderView : UIView

@property (nonatomic,strong) IBOutlet UILabel     * title;
@end
