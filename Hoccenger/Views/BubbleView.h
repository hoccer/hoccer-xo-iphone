//
//  BubbleView.h
//  Hoccenger
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AutoheightLabel;

@interface BubbleView : UIView

@property (nonatomic) UIEdgeInsets padding;
@property (strong, nonatomic) IBOutlet AutoheightLabel* message;
//@property (nonatomic) double minHeight;
@property (strong, nonatomic) UIColor* bubbleColor;


- (id) initWithCoder:(NSCoder *)aDecoder;
- (void) awakeFromNib;

- (double) heightForText: (NSString*) text;

@end
