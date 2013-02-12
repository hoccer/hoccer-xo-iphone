//
//  DetailViewController.h
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) Contact* partner;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end
