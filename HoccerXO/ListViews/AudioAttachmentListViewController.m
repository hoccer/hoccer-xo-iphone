//
//  AudioAttachmentListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioAttachmentListViewController.h"

#import "AddToCollectionListViewController.h"
#import "AppDelegate.h"
#import "Attachment.h"
#import "AudioAttachmentCell.h"
#import "AudioPlayerStateItemController.h"
#import "Collection.h"
#import "Contact.h"
#import "HXOAudioPlayer.h"
#import "HXOUI.h"
#import "HXOThemedNavigationController.h"
#import "tab_attachments.h"


@interface AudioAttachmentListViewController ()

@property (nonatomic, strong) NSFetchedResultsController     * fetchedResultsController;
@property (nonatomic, strong) UIView                         * footerContainerView;
@property (nonatomic, strong) NSManagedObjectContext         * managedObjectContext;
@property (nonatomic, strong) NSManagedObjectModel           * managedObjectModel;
@property (nonatomic, strong) AudioPlayerStateItemController * audioPlayerStateItemController;

@end


@implementation AudioAttachmentListViewController

#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.tabBarItem.image = [[[tab_attachments alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
    
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self registerCellClass:[AudioAttachmentCell class]];
    self.audioPlayerStateItemController = [[AudioPlayerStateItemController alloc] initWithViewController:self];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self preferredContentSizeChanged:nil];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];

    if (self.footerContainerView == nil) {
        CGRect tabBarFrame = self.tabBarController.tabBar.frame;
        self.footerContainerView = [[UIView alloc] initWithFrame:tabBarFrame];
        self.footerContainerView.backgroundColor = [[HXOUI theme] navigationBarBackgroundColor];
        
        CGFloat x = tabBarFrame.size.width / 3.0;
        
        self.sendButton = [self createFooterButton];
        self.sendButton.frame = CGRectMake(0.0, 0.0, x, tabBarFrame.size.height);
        [self.sendButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_send", nil) forState:UIControlStateNormal];
        [self.sendButton addTarget: self action:@selector(addToCollectionPressed:) forControlEvents: UIControlEventTouchUpInside];

        self.deleteButton = [self createFooterButton];
        self.deleteButton.frame = CGRectMake(x, 0.0, x, tabBarFrame.size.height);
        [self.deleteButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_delete", nil) forState:UIControlStateNormal];
        [self.deleteButton addTarget: self action:@selector(addToCollectionPressed:) forControlEvents: UIControlEventTouchUpInside];

        self.addToCollectionButton = [self createFooterButton];
        self.addToCollectionButton.frame = CGRectMake(2.0 * x, 0.0, x, tabBarFrame.size.height);
        [self.addToCollectionButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_add", nil) forState:UIControlStateNormal];
        [self.addToCollectionButton addTarget: self action:@selector(addToCollectionPressed:) forControlEvents: UIControlEventTouchUpInside];
    }

    [self updateNavigationBar];
}

- (UIButton *)createFooterButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = self.view.tintColor;
    [self.footerContainerView addSubview:button];

    return button;
}

- (void)updateNavigationBar {
    if (self.collection) {
        self.navigationItem.title = self.collection.name;
    } else if (self.contact) {
        self.navigationItem.title = self.contact.displayName;
    } else {
        self.navigationItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
        if (self.tableView.isEditing) {
            self.navigationItem.leftBarButtonItem = nil;
        } else {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"collection_list_nav_title", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showCollections:)];
        }
    }
    
    UIBarButtonSystemItem item = self.tableView.isEditing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:item target:self action:@selector(toggleEditMode:)];
}

- (void)updateFooter {
    if (self.tableView.isEditing) {
        [self.tabBarController.tabBar.superview insertSubview:self.footerContainerView aboveSubview:self.tabBarController.view];
    } else {
        [self.footerContainerView removeFromSuperview];
    }
    
    [self updateFooterButtons];
}

- (void)updateFooterButtons {
    BOOL enabled = [[self.tableView indexPathsForSelectedRows] count] > 0;

    self.addToCollectionButton.enabled = enabled;
    self.deleteButton.enabled = enabled;
    self.sendButton.enabled = enabled;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    _fetchedResultsController = nil;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

#pragma mark - Configuration

- (void) setCollection:(Collection *)collection {
    self.fetchedResultsController = nil;
    _collection = collection;
    [self.tableView reloadData];
}

- (void) setContact:(Contact *)contact {
    self.fetchedResultsController = nil;
    _contact = contact;
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void) showCollections:(id)sender {
    [self performSegueWithIdentifier:@"showCollections" sender:sender];
}

- (void) toggleEditMode:(id)sender {
    [self.tableView setEditing:!self.tableView.isEditing animated:YES];
    [self updateNavigationBar];
    [self updateFooter];
}

- (void) addToCollectionPressed:(id)sender {
    [self performSegueWithIdentifier:@"showAddToCollection" sender:sender];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showAddToCollection"] && [segue.destinationViewController isKindOfClass:[HXOThemedNavigationController class]]) {
        HXOThemedNavigationController *navigationController = segue.destinationViewController;

        if ([navigationController.topViewController isKindOfClass:[AddToCollectionListViewController class]]) {
            AddToCollectionListViewController *addToCollectionListViewController = (AddToCollectionListViewController *)navigationController.topViewController;
            addToCollectionListViewController.addToCollectionListViewControllerDelegate = self;
        }
    }
}

#pragma mark - AddToCollectionListViewControllerDelegate

- (void)addToCollectionListViewController:(id)controller didSelectCollection:(Collection *)collection {
    [controller dismissViewControllerAnimated:YES completion:nil];
    [collection appendAttachments:[self selectedAttachments]];
    [[AppDelegate instance] saveDatabase];
    [self toggleEditMode:nil];
}

- (NSArray *)selectedAttachments {
    NSMutableArray *attachments = [[NSMutableArray alloc] init];
    NSArray *selectedIndexPaths = [self.tableView indexPathsForSelectedRows];
    
    for (NSIndexPath *indexPath in selectedIndexPaths) {
        [attachments addObject:[self attachmentAtIndexPath:indexPath]];
    }
    
    return [NSArray arrayWithArray:attachments];
}

#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[AppDelegate instance] managedObjectContext];
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (_managedObjectModel == nil) {
        _managedObjectModel = [[AppDelegate instance] managedObjectModel];
    }
    return _managedObjectModel;
}

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact collection:(Collection *)collection managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    NSDictionary *vars = @{ @"contact" : contact ? contact : [NSNull null],
                            @"collection" : collection ? collection : [NSNull null] };

    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestFromTemplateWithName:@"ReceivedAudioAttachments" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"message.timeReceived" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

#pragma mark - Table view data source

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController == nil) {
        NSFetchRequest *fetchRequest = [self.class fetchRequestForContact:self.contact collection:self.collection managedObjectModel:self.managedObjectModel];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
        _fetchedResultsController.delegate = self;
        [_fetchedResultsController performFetch:nil];
    }

    return _fetchedResultsController;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id<NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AudioAttachmentCell *cell = [tableView dequeueReusableCellWithIdentifier:[AudioAttachmentCell reuseIdentifier] forIndexPath:indexPath];
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
        Attachment *attachment = [self attachmentAtIndexPath:indexPath];
        [[AppDelegate instance] deleteObject:attachment.message];
        [[AppDelegate instance] saveDatabase];
    }
}

- (void) configureCell:(AudioAttachmentCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    Attachment *attachment = [self attachmentAtIndexPath:indexPath];
    cell.attachment = attachment;
}

- (Attachment *) attachmentAtIndexPath:(NSIndexPath *)indexPath {
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if ([object isKindOfClass:[Attachment class]]) {
        return (Attachment *)object;
    }
    
    return nil;
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    self.tableView.rowHeight = [self calculateRowHeight];
    [self.tableView reloadData];
}

- (CGFloat) calculateRowHeight {
    // HACK: Add one to fix layout constraint errors
    UITableViewCell *prototypeCell = [self prototypeCellOfClass:[AudioAttachmentCell class]];
    return ceilf([prototypeCell systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height) + 1;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        [self updateFooterButtons];
    } else {
        // The fetchedObjects array seems to change, so we take an immutable copy
        NSArray * playlist = [[self.fetchedResultsController fetchedObjects] copy];
        
        HXOAudioPlayer *audioPlayer = [HXOAudioPlayer sharedInstance];
        BOOL success = [audioPlayer playWithPlaylist:playlist atTrackNumber:indexPath.row];
        
        if (success) {
            UIViewController *audioPlayerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AudioPlayerViewController"];
            [self presentViewController:audioPlayerViewController animated:YES completion:NULL];
        } else {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"attachment_cannot_play_title", nil)
                                                             message: NSLocalizedString(@"attachment_cannot_play_message", nil)
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        [self updateFooterButtons];
    }
}

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
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
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

@end
