//
//  HXOHyperLabel.h
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

FOUNDATION_EXTERN NSString * kHXOLinkAttributeName;

@class HXOHyperLabel;

@protocol HXOHyperLabelDelegate <NSObject>

- (void) hyperLabel: (HXOHyperLabel*) label didPressLink: (id) link long: (BOOL) longPress;


@end

@interface NSMutableAttributedString (HXOHyperLabel)

- (void) addLinksMatching:(NSRegularExpression *)regex;

@end

@interface HXOHyperLabel : UIControl

@property (nonatomic,strong) NSAttributedString * attributedText;
@property (nonatomic,strong) UIFont *             font;
@property (nonatomic,strong) UIColor *            textColor;
@property (nonatomic,strong) UIColor *            linkColor;
@property (nonatomic,assign) NSTextAlignment      textAlignment;
@property (nonatomic,assign) NSLineBreakMode      lineBreakMode;

@property (nonatomic,assign) CGFloat              preferredMaxLayoutWidth;

@property (nonatomic,weak) id<HXOHyperLabelDelegate> delegate;

@end
