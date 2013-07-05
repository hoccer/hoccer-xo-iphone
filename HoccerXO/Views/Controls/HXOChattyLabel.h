//
//  HXOChattyLabel.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HXOChattyLabel;

@protocol HXOChattyLabelDelegate <NSObject>

- (void) chattyLabel: (HXOChattyLabel*) label didTapToken: (NSTextCheckingResult*) match ofClass: (id) tokenClass;

@end

@interface HXOChattyLabel : UILabel

@property (nonatomic,weak) IBOutlet id<HXOChattyLabelDelegate> delegate;
@property (nonatomic,strong) NSDictionary*                     defaultTokenStyle;

- (void) registerTokenClass: (id) tokenClass withExpression: (NSRegularExpression*) regex style: (NSDictionary*) style;

@end
