//
//  HXOLinkableLabel.h
//  HoccerXO
//
//  Created by David Siegel on 03.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HXOLinkableLabel;

@protocol HXOLinkableLabelDelegate <NSObject>

@optional
- (void) didClickLinkOfClass: (id) tokenClass withToken: (NSString*) token;

- (NSDictionary*) linkClassExpressionsForLabel: (HXOLinkableLabel*) label;
- (NSDictionary*) label: (HXOLinkableLabel*) label stringAttributesForClass: (NSString*) tokenClass;

@end

@interface HXOLinkableLabel : UIView
{
    NSArray * _tokens;
    UILabel * _label;
    NSArray * _buttons;
}

@property (nonatomic,assign) CGFloat emojiScale;

@property(nonatomic, getter=isEnabled) BOOL enabled;
@property(nonatomic, retain) UIFont *font;
@property(nonatomic, getter=isHighlighted) BOOL highlighted;
@property(nonatomic, retain) UIColor *highlightedTextColor;
@property(nonatomic) NSLineBreakMode lineBreakMode;
@property(nonatomic) NSInteger numberOfLines;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) NSTextAlignment textAlignment;
@property(nonatomic, retain) UIColor *textColor;
@property (nonatomic,assign) id<HXOLinkableLabelDelegate> delegate;

@end
