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

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, readonly) NSManagedObjectContext   *managedObjectContext;
@property (nonatomic, readonly) NSManagedObjectModel     *managedObjectModel;

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

#pragma mark - Core Data stack

- (NSManagedObjectContext *)managedObjectContext {
    return [[AppDelegate instance] managedObjectContext];
}

- (NSManagedObjectModel *)managedObjectModel {
    return [[AppDelegate instance] managedObjectModel];
}

#pragma mark - Table view data source

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController == nil) {
        NSFetchRequest *fetchRequest = [[self.managedObjectModel fetchRequestTemplateForName:@"Collections"] copy];
        NSArray *sortDescriptors = @[ [[NSSortDescriptor alloc] initWithKey:@"name" ascending: YES] ];
        [fetchRequest setSortDescriptors:sortDescriptors];

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];

        [_fetchedResultsController performFetch:nil];
    }
    
    return _fetchedResultsController;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier = @"collection_cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    }

    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo name];
}

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Collection *collection = [self collectionAtIndexPath:indexPath];
        [[AppDelegate instance] deleteObject:collection];
        [[AppDelegate instance] saveDatabase];
    }
}

- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Collection *collection = [self collectionAtIndexPath:indexPath];
    cell.textLabel.text = collection.name;
}

- (Collection *) collectionAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if ([object isKindOfClass:[Collection class]]) {
        return (Collection *)object;
    }
    
    return nil;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.firstOtherButtonIndex) {
        Collection *collection = [NSEntityDescription insertNewObjectForEntityForName:[Collection entityName] inManagedObjectContext:[[AppDelegate instance] managedObjectContext]];
        collection.name = [self textInAlertView:alertView];
        [[AppDelegate instance] saveDatabase];
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
