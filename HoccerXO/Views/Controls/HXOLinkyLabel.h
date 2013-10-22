//
//  HXOChattyLabel.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HXOLinkyLabel;

@protocol HXOLinkyLabelDelegate <NSObject>

- (void) chattyLabel: (HXOLinkyLabel*) label didTapToken: (NSTextCheckingResult*) match ofClass: (id) tokenClass isLongPress: (BOOL) isLongPress;

@end

@interface HXOLinkyLabel : UILabel

@property (nonatomic,weak)     IBOutlet id<HXOLinkyLabelDelegate> delegate;
@property (nonatomic,strong)   NSDictionary*                      defaultTokenStyle;
@property (nonatomic,readonly) NSUInteger                         currentNumberOfLines;
@property (nonatomic,readonly) NSMutableArray *                   tokenClasses;

- (void) registerTokenClass: (id) tokenClass withExpression: (NSRegularExpression*) regex style: (NSDictionary*) style;

@end
