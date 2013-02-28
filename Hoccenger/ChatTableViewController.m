//
//  ChatTableViewController.m
//  Hoccenger
//
//  Created by David Siegel on 13.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatTableViewController.h"
#import "AppDelegate.h"
#import "Message.h"
#import "MessageCell.h"
#import "SectionHeaderCell.h"

@interface ChatTableViewController ()

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@end

@implementation ChatTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.messageCell = [self.tableView dequeueReusableCellWithIdentifier: [MessageCell reuseIdentifier]];


    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: [MessageCell reuseIdentifier] forIndexPath:indexPath];

    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    [self configureCell: cell atIndexPath: indexPath];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SectionHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier: @"SectionHeaderCell"];
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    cell.label.text = sectionInfo.name;
    cell.label.shadowColor  = [UIColor whiteColor];
    cell.label.shadowOffset = CGSizeMake(0.0, 1.0);
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo name];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // TODO: iPad sizes, &c.
    // this ain't nice. it shouldn't be neccessary to hard code the screen size here...
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    float width = UIDeviceOrientationIsPortrait(self.interfaceOrientation) ? screenSize.width : screenSize.height;

    Message * message = [self.fetchedResultsController objectAtIndexPath:indexPath];

    CGRect oldFrame = self.messageCell.frame;
    self.messageCell.frame = CGRectMake(oldFrame.origin.x, oldFrame.origin.y, width, oldFrame.size.height);
    return [self.messageCell heightForText: message.text];
}

#pragma mark - Fetched results controller

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectContext != nil) {
        return _managedObjectModel;
    }

    _managedObjectModel = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectModel;
    return _managedObjectModel;
}


// XXX use a better key than the nickName
- (void) setPartner: (Contact*) partner {
    if (partner == nil) {
        return;
    }
    if (resultsControllers == nil) {
        resultsControllers = [[NSMutableDictionary alloc] init];
    }
    _fetchedResultsController = [resultsControllers objectForKey: partner.nickName];
    if (_fetchedResultsController == nil) {
        NSDictionary * vars = @{ @"nickName" : partner.nickName };
        NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByNickName" substitutionVariables: vars];

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending: YES];
        NSArray *sortDescriptors = @[sortDescriptor];

        [fetchRequest setSortDescriptors:sortDescriptors];

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath: @"timeSection" cacheName: [NSString stringWithFormat: @"Messages-%@", partner.nickName]];
        _fetchedResultsController.delegate = self;

        [resultsControllers setObject: _fetchedResultsController forKey: partner.nickName];

        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    [self.tableView reloadData];
    [self scrollToBottom: NO];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            /* TODO: find out how to do this...
             [tableView scrollToRowAtIndexPath: newIndexPath atScrollPosition: UITableViewScrollPositionTop animated:YES];
             */
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    // XXX not generic ... see TODO above
    [self scrollToBottom: YES];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self scrollToBottom: NO];
}

- (void)configureCell:(MessageCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Message * message = (Message*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    cell.message.text = message.text;
    if ([message.isOutgoing boolValue] == YES) {
        cell.myAvatar.hidden = NO;
        cell.myAvatar.image = [UIImage imageNamed: @"azrael.png"];
        cell.yourAvatar.hidden = YES;
    } else {
        cell.yourAvatar.hidden = NO;
        cell.yourAvatar.image = [UIImage imageWithData: message.contact.avatar];
        cell.myAvatar.hidden = YES;
    }
}

- (void) scrollToBottom: (BOOL) animated {
    // XXX handle sections
    if ([self.fetchedResultsController.fetchedObjects count]) {
        NSInteger lastSection = [self numberOfSectionsInTableView: self.tableView] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:  [self tableView: self.tableView numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
        [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionBottom animated: animated];
    }
}

@end
