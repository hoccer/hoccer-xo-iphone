//
//  TestingGroundViewController.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOLinkyLabel.h"

@interface TestingGroundViewController : UIViewController <HXOLinkyLabelDelegate>

@property (nonatomic,weak) IBOutlet HXOLinkyLabel * label;

@end
