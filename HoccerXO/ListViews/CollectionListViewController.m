//
//  CollectionListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CollectionListViewController.h"

#import "AppDelegate.h"
#import "Collection.h"

@interface CollectionListViewController ()

@end

@implementation CollectionListViewController

#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSString *title = NSLocalizedString(@"collection_list_nav_title", nil);
    self.navigationItem.title = title;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(newCollection:)];
}

#pragma mark - Actions

- (void)newCollection:(id)sender {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"collection_new_collection_title", nil)
                                                    message:NSLocalizedString(@"collection_new_collection_message", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"save", nil), nil];
    
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.firstOtherButtonIndex) {
        Collection *collection = [NSEntityDescription insertNewObjectForEntityForName:[Collection entityName] inManagedObjectContext:[[AppDelegate instance] managedObjectContext]];
        collection.name = [self textInAlertView:alertView];
    }
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView {
    // disable save button as long as no name is entered
    return [[self textInAlertView:alertView] length] > 0;
}

- (NSString *)textInAlertView:(UIAlertView *)alertView {
    return [[alertView textFieldAtIndex:0] text];
}

@end
