//
//  SegmentedViewController.h
//  HoccerXO
//
//  Created by David Siegel on 22.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SegmentedViewController : UIViewController

@property (nonatomic,strong) NSArray * childViewControllerStoryboardIDs;
@property (nonatomic,strong) NSArray * childViewControllerTitles;

@end
