//
//  TestingGroundViewController.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOLinkyLabel.h"

@class BubbleViewToo;

@interface TestingGroundViewController : UIViewController <HXOLinkyLabelDelegate>

@property (nonatomic,weak) IBOutlet HXOLinkyLabel * label;

@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble1;
@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble2;
@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble3;
@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble4;
@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble5;
@property (nonatomic,weak) IBOutlet BubbleViewToo * bubble6;

@end
