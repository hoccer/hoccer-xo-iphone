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

@interface TestingGroundViewController : UIViewController <HXOLinkyLabelDelegate,UITableViewDataSource,UITableViewDelegate>
{
    NSArray * _items;
    NSMutableDictionary * _cellPrototypes;
}

@property (nonatomic,weak) IBOutlet HXOLinkyLabel * label;

@property (nonatomic,weak) IBOutlet UITableView * tableView;

@end
