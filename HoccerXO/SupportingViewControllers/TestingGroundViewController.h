//
//  TestingGroundViewController.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOChattyLabel.h"

@interface TestingGroundViewController : UIViewController <HXOChattyLabelDelegate>

@property (nonatomic,weak) IBOutlet HXOChattyLabel * label;

@end
