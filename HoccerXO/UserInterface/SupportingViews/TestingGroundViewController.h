//
//  TestingGroundViewController.h
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOHyperLabel.h"

@class BubbleViewToo;

@interface TestingGroundViewController : UIViewController <HXOHyperLabelDelegate,UITableViewDataSource,UITableViewDelegate>
{
    NSArray * _items;
    NSMutableDictionary * _cellPrototypes;
}

@property (nonatomic,weak) IBOutlet HXOHyperLabel * label;

@property (nonatomic,weak) IBOutlet UITableView * tableView;

@end
