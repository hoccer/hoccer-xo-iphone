//
//  AudioAttachmentListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentListViewController.h"

#import "AppDelegate.h"
#import "Attachment.h"
#import "tab_settings.h"


@interface AudioAttachmentListViewController ()

@property (nonatomic, strong) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic, strong) NSManagedObjectContext     * managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel       * managedObjectModel;

@end


static NSString *reuseIdentifier = @"audio_attachment";


@implementation AudioAttachmentListViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    NSString *title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
    self.tabBarItem.image = [[[tab_settings alloc] init] image];
    self.tabBarItem.title = title;
    self.navigationItem.title = title;

    NSDictionary *vars = @{ @"mediaType" : @"audio" };
    NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsByMediaType" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"humanReadableFileName" ascending: YES];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    [self.fetchedResultsController performFetch:nil];
}

- (void)viewDidLoad {
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:reuseIdentifier];
}

#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel == nil) {
        _managedObjectModel = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectModel;
    }
    return _managedObjectModel;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    [self configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo name];
}

- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if ([object isKindOfClass:[Attachment class]]) {
        Attachment *attachment = (Attachment *)object;
        cell.textLabel.text = attachment.humanReadableFileName;
    }
}

@end
