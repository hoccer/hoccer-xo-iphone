//
//  ChatTableViewCell.h
//  ChatSpike
//
//  Created by David Siegel on 05.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChatCell : UITableViewCell
{
    BOOL isIncoming;
}

+ (ChatCell*) cell;
+ (NSString *)reuseIdentifier;
+ (float) heightForText: (NSString*) text;

- (void) layout: (BOOL) isIncoming;

@property (nonatomic) NSString* messageText;
@property (nonatomic) UIImage* avatar;
@property (nonatomic) NSString* nickName;

@end
