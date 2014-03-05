//
//  ContactCell.h
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ContactCell.h"

@interface ConversationCell : ContactCell

@property (nonatomic,readonly) HXOLabel * dateLabel;

@property (nonatomic,assign) BOOL hasNewMessages;

@end
