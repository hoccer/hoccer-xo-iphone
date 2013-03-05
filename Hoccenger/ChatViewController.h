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

@class ChatBackend;

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate>
{
    ChatTableViewController * chatTableController;
}

@property (strong, nonatomic) Contact* partner;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) ChatBackend * chatBackend;

@property (strong, nonatomic) IBOutlet UITextField * textField;
@property (strong, nonatomic) IBOutlet UIButton *    sendButton;
@property (strong, nonatomic) IBOutlet UIView *      chatbar;

- (IBAction)sendPressed:(id)sender;

@end
