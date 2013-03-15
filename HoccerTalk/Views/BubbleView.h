//
//  BubbleView.h
//  HoccerTalk
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AutoheightLabel;
@class Message;

@interface BubbleView : UIView

@property (nonatomic) UIEdgeInsets padding;
@property (strong, nonatomic) IBOutlet AutoheightLabel* message;
@property (strong, nonatomic) UIColor* bubbleColor;
@property (nonatomic) BOOL pointingRight;
@property (strong,nonatomic) UIView * attachmentView;


- (id) initWithCoder:(NSCoder *)aDecoder;
- (void) awakeFromNib;

- (CGFloat) heightForMessage: (Message*) message;

@end
