//
//  DetailViewController.h
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"
#import "ChatTableViewController.h"

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate>
{
    ChatTableViewController * chatTableController;
}

@property (strong, nonatomic) Contact* partner;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;


@property (weak, nonatomic) IBOutlet UITextField * textField;
@property (weak, nonatomic) IBOutlet UIButton *    sendButton;

- (IBAction)sendPressed:(id)sender;

@end
