//
//  AutosizeLabel.h
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AutoheightLabel : UILabel

@property (nonatomic) UIEdgeInsets padding;

@property (nonatomic) double minHeight;
@property (nonatomic) double arrowWidth;
@property (nonatomic) BOOL arrowLeft;
@property (nonatomic) UIColor * bubbleColor;


- (CGSize) calculateSize: (NSString*) text;

@end
