//
//  ChatTableViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 13.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//


#import "ChatTableViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AppDelegate.h"
#import "Message.h"
#import "LeftMessageCell.h"
#import "RightMessageCell.h"
#import "SectionHeaderCell.h"
#import "AvatarBezelView.h"
#import "AutoheightLabel.h"
#import "BubbleView.h"
#import "ImageAttachment.h"

@interface ChatTableViewController ()

@property (nonatomic,strong) NSIndexPath * firstNewMessage;
@property (strong) MessageCell* messageCell;
@property (strong) UITableViewCell* headerCell;

- (void)configureCell:(UITableViewCell *)cell forMessage:(Message *) message;

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

    self.messageCell = [self.tableView dequeueReusableCellWithIdentifier: [LeftMessageCell reuseIdentifier]];
    self.headerCell  = [self.tableView dequeueReusableCellWithIdentifier: [SectionHeaderCell reuseIdentifier]];

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
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Message * message = (Message*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    MessageCell *cell = (MessageCell*)[tableView dequeueReusableCellWithIdentifier: ([message.isOutgoing isEqualToNumber: @YES] ? [RightMessageCell reuseIdentifier] : [LeftMessageCell reuseIdentifier]) forIndexPath:indexPath];

    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    [self configureCell: cell forMessage: message];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SectionHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier: [SectionHeaderCell reuseIdentifier]];
    cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    cell.label.text = sectionInfo.name;
    cell.label.shadowColor  = [UIColor whiteColor];
    cell.label.shadowOffset = CGSizeMake(0.0, 1.0);
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo name];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // XXX the -1 avoids a view glitch. A light gray line appears without it. I think that is
    //     because the table view assuemes there is a 1px separator. However, sometimes the
    //     grey line still appears ... 
    return self.headerCell.frame.size.height - 1;
}

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
    double width = self.tableView.frame.size.width;

    Message * message = [self.fetchedResultsController objectAtIndexPath:indexPath];

    CGRect frame = self.messageCell.frame;
    self.messageCell.frame = CGRectMake(frame.origin.x, frame.origin.y, width, frame.size.height);

    float height = [self.messageCell heightForText: message.body];

    if (message.attachment && [message.attachment isKindOfClass: [ImageAttachment class]]) {
        ImageAttachment * imageAttachment = (ImageAttachment*)message.attachment;
        height += ([imageAttachment.height floatValue] / [imageAttachment.width floatValue]) * self.messageCell.message.frame.size.width;
    }
    return height;
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


- (void) setPartner: (Contact*) partner {
    if (partner == nil) {
        return;
    }
    if (resultsControllers == nil) {
        resultsControllers = [[NSMutableDictionary alloc] init];
    }
    if (_fetchedResultsController != nil) {
        _fetchedResultsController.delegate = nil;
    }
    _fetchedResultsController = [resultsControllers objectForKey: partner.objectID];
    if (_fetchedResultsController == nil) {
        NSDictionary * vars = @{ @"contact" : partner };
        NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByContact" substitutionVariables: vars];

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending: YES];
        NSArray *sortDescriptors = @[sortDescriptor];

        [fetchRequest setSortDescriptors:sortDescriptors];

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath: @"timeSection" cacheName: [NSString stringWithFormat: @"Messages-%@", partner.objectID]];
        _fetchedResultsController.delegate = self;

        [resultsControllers setObject: _fetchedResultsController forKey: partner.objectID];

        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    } else {
        _fetchedResultsController.delegate = self;
    }
    self.firstNewMessage = nil;
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
            if (self.firstNewMessage == nil) {
                self.firstNewMessage = newIndexPath;
            }
            break;
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
        {
            Message * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] forMessage: message];
            break;
        }

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    if (self.firstNewMessage != nil) {
        [self.tableView scrollToRowAtIndexPath: self.firstNewMessage atScrollPosition: UITableViewScrollPositionBottom animated: YES];
        self.firstNewMessage = nil;
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self scrollToBottom: NO];
}

- (void)configureCell:(MessageCell *)cell forMessage:(Message *) message {

    if ([message.isRead isEqualToNumber: @NO]) {
        message.isRead = @YES;
    }

    cell.message.text = message.body;
    cell.avatar.image = [message.isOutgoing isEqualToNumber: @YES] ? [UIImage imageNamed: @"azrael"] : message.contact.avatarImage;
    
    if (message.attachment && [message.attachment isKindOfClass: [ImageAttachment class]]) {
        UIImageView * imageView = [[UIImageView alloc] initWithImage: [UIImage imageWithContentsOfFile: message.attachment.filePath]];
        /*
        imageView.layer.shadowColor = [UIColor blackColor].CGColor;
        imageView.layer.shadowOffset = CGSizeMake(0, 2);
        imageView.layer.shadowOpacity = 0.8;
        imageView.layer.shadowRadius = 3;
        imageView.layer.masksToBounds = NO;
         */
        cell.bubble.attachmentView = imageView;
    } else {
        cell.bubble.attachmentView = nil;
    }
}

- (void) scrollToBottom: (BOOL) animated {
    if ([self.fetchedResultsController.fetchedObjects count]) {
        NSInteger lastSection = [self numberOfSectionsInTableView: self.tableView] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:  [self tableView: self.tableView numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
        [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionBottom animated: animated];
    }
}

@end
