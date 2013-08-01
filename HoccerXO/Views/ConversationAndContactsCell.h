//
//  ConversationAndContactsCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"

@class InsetImageView2;

@interface ConversationAndContactsCell : HXOTableViewCell

@property (nonatomic,strong) IBOutlet UILabel * nickName;
@property (nonatomic,strong) IBOutlet InsetImageView2 * avatar;
@property (nonatomic,strong) IBOutlet UILabel * statusLabel;

- (void) engraveLabel: (UILabel*) label;
- (NSString*) backgroundName;

@end
