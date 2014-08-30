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
#import "Collection.h"
#import "CollectionDataSource.h"
#import "Contact.h"
#import "ContactCell.h"
#import "ContactPicker.h"
#import "Group.h"
#import "HXOAudioAttachmentDataSourcePlaylist.h"
#import "HXOAudioPlayer.h"
#import "HXOPluralocalization.h"
#import "HXOThemedNavigationController.h"
#import "HXOUI.h"
#import "MusicBrowserDataSource.h"
#import "tab_attachments.h"


@interface AudioAttachmentListViewController ()

@property (nonatomic, strong) UIView                         * footerContainerView;
@property (nonatomic, strong) AudioAttachmentDataSource      * dataSource;
@property (nonatomic, strong) NSArray                        * attachmentsToDelete;

@end


@implementation AudioAttachmentListViewController

#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.tabBarItem.image = [[[tab_attachments alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self registerCellClass:[AudioAttachmentCell class]];
    [self updateDataSource];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self preferredContentSizeChanged:nil];
    
    self.tableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.footerContainerView == nil) {
        CGRect tabBarFrame = self.tabBarController.tabBar.frame;
        self.footerContainerView = [[UIView alloc] initWithFrame:tabBarFrame];
        self.footerContainerView.backgroundColor = [[HXOUI theme] navigationBarBackgroundColor];
        
        CGFloat x = tabBarFrame.size.width / 3.0;
        
        self.sendButton = [self createFooterButton];
        self.sendButton.frame = CGRectMake(0.0, 0.0, x, tabBarFrame.size.height);
        [self.sendButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_send", nil) forState:UIControlStateNormal];
        [self.sendButton addTarget:self action:@selector(sendPressed:) forControlEvents:UIControlEventTouchUpInside];

        self.deleteButton = [self createFooterButton];
        self.deleteButton.frame = CGRectMake(x, 0.0, x, tabBarFrame.size.height);
        [self.deleteButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_delete", nil) forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(deletePressed:) forControlEvents:UIControlEventTouchUpInside];

        self.addToCollectionButton = [self createFooterButton];
        self.addToCollectionButton.frame = CGRectMake(2.0 * x, 0.0, x, tabBarFrame.size.height);
        [self.addToCollectionButton setTitle:NSLocalizedString(@"audio_attachment_list_footer_add", nil) forState:UIControlStateNormal];
        [self.addToCollectionButton addTarget:self action:@selector(addToCollectionPressed:) forControlEvents:UIControlEventTouchUpInside];
    }

    [self updateNavigationBar];
}

- (void)wasSelectedByTabBarController:(UITabBarController *)tabBarController {
    HXOAudioPlayer *audioPlayer = [HXOAudioPlayer sharedInstance];
    
    if ([audioPlayer isPlaying]) {
        Attachment *nowPlayingAttachment = [audioPlayer attachment];
        NSIndexPath *indexPath = [self.dataSource indexPathForAttachment:nowPlayingAttachment];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

- (UIButton *)createFooterButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = self.view.tintColor;
    [self.footerContainerView addSubview:button];

    return button;
}

- (void)updateNavigationBar {
    UIBarButtonSystemItem editButton = self.tableView.isEditing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit;
    self.navigationItem.hidesBackButton = self.tableView.isEditing;

    // list of a collection
    if (self.collection) {
        self.navigationItem.title = self.collection.name;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:editButton target:self action:@selector(toggleEditMode:)];

    } else if (self.contact) {
        self.navigationItem.title = self.contact.nickNameOrAlias;

    // list of all music items
    } else {
        self.navigationItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
        if (self.tableView.isEditing) {
            self.navigationItem.rightBarButtonItem = nil;
        } else {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"collection_list_nav_title", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showCollections:)];
        }
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:editButton target:self action:@selector(toggleEditMode:)];
    }
}

- (void)updateFooter {
    if (self.tableView.isEditing) {
        [self.tabBarController.view insertSubview:self.footerContainerView aboveSubview:self.tabBarController.view];
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
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

#pragma mark - Configuration

- (void) setCollection:(Collection *)collection {
    _collection = collection;
    [self updateDataSource];
}

- (void) setContact:(Contact *)contact {
    _contact = contact;
    [self updateDataSource];
}

- (void) updateDataSource {
    if (self.collection) {
        self.dataSource = [[CollectionDataSource alloc] initWithCollection:self.collection];
    } else if (self.contact) {
        self.dataSource = [[MusicBrowserDataSource alloc] initWithContact:self.contact];
    } else {
        self.dataSource = [[MusicBrowserDataSource alloc] init];
    }

    self.dataSource.delegate = self;
    self.tableView.dataSource = self.dataSource;
    self.searchDisplayController.searchResultsDataSource = self.dataSource;
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void) showCollections:(id)sender {
    [self performSegueWithIdentifier:@"showCollections" sender:sender];
}

- (void) toggleEditMode:(id)sender {
    if (!self.tableView.editing) {
        // work around weird API, see http://stackoverflow.com/questions/9683516
        self.tableView.allowsMultipleSelectionDuringEditing = YES;
    }
    
    [self.tableView setEditing:!self.tableView.isEditing animated:YES];

    if (!self.tableView.editing) {
        // work around weird API, see http://stackoverflow.com/questions/9683516
        self.tableView.allowsMultipleSelectionDuringEditing = NO;
        
        // save changes
        [[AppDelegate instance] saveDatabase];
    }
    
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

- (void) deletePressed:(id)sender {
    [self askToDeleteAttachments:[self selectedAttachments]];
}

- (void) askToDeleteAttachments:(NSArray *)attachments {
    NSAssert(self.attachmentsToDelete == nil, @"AttachmentsToDelete not reset properly");

    self.attachmentsToDelete = attachments;
    NSString *attachmentCount = [NSString stringWithFormat:HXOPluralocalizedString(@"audio_attachment_list_count_attachments", [attachments count], NO), [attachments count]];

    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    actionSheet.title = [NSString stringWithFormat:NSLocalizedString(@"audio_attachment_list_confirm_delete_title", nil), attachmentCount];

    if (self.collection) {
        [actionSheet addButtonWithTitle:NSLocalizedString(@"audio_attachment_list_remove_from_collection", nil)];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"delete", nil)];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"cancel", nil)];

        actionSheet.destructiveButtonIndex = 1;
        actionSheet.cancelButtonIndex = 2;
    } else {
        [actionSheet addButtonWithTitle:NSLocalizedString(@"delete", nil)];
        [actionSheet addButtonWithTitle:NSLocalizedString(@"cancel", nil)];
        
        actionSheet.destructiveButtonIndex = 0;
        actionSheet.cancelButtonIndex = 1;
    }

    actionSheet.delegate = self;
    [actionSheet showFromTabBar:self.tabBarController.tabBar];
}

- (void) sendPressed:(id)sender {
    ContactPickerCompletion completion = ^(NSArray *contacts) {
        if (contacts != nil) {
            NSArray *selectedAttachments = [self selectedAttachments];

            for (Contact *contact in contacts) {
                for (Attachment *attachment in selectedAttachments) {
                    [[[AppDelegate instance] chatBackend] sendMessage:@"" toContactOrGroup:contact toGroupMemberOnly:nil withAttachment:[attachment clone]];
                }
            }
        
            [self toggleEditMode:nil];
        }
    };
    
    NSPredicate *contactPredicate = [NSPredicate predicateWithFormat:@"type == %@ AND relationshipState == 'friend'", [Contact entityName]];
    NSPredicate *nearbyContactPredicate = [NSPredicate predicateWithFormat:@"type == %@ AND SUBQUERY(groupMemberships, $member, $member.group.groupType == %@ AND $member.group.groupState == %@).@count > 0", [Contact entityName], kGroupTypeNearby, kGroupStateExists];
    NSPredicate *groupAndNearbyGroupPredicate = [NSPredicate predicateWithFormat:@"type == %@ AND myGroupMembership.state == 'joined'", [Group entityName]];

    NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[ contactPredicate,
                                                                                  nearbyContactPredicate,
                                                                                  groupAndNearbyGroupPredicate ]];

    id picker = [ContactPicker contactPickerWithTitle:NSLocalizedString(@"contact_list_nav_title", nil)
                                                types:ContactPickerTypeContact | ContactPickerTypeGroup
                                                style:ContactPickerStyleMulti
                                            predicate:predicate
                                           completion:completion];
    
    [self presentViewController:picker animated:YES completion:nil];
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
        [attachments addObject:[self.dataSource attachmentAtIndexPath:indexPath]];
    }
    
    return [NSArray arrayWithArray:attachments];
}

#pragma mark - Action Sheet Delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    BOOL usedSwipeToDelete = !self.tableView.allowsMultipleSelectionDuringEditing;
    BOOL delete = buttonIndex == actionSheet.destructiveButtonIndex;
    BOOL cancel = buttonIndex == actionSheet.cancelButtonIndex;

    if (delete) {
        // delete attachments
        for (Attachment *attachment in self.attachmentsToDelete) {
            [[AppDelegate instance] deleteObject:attachment.message];
        }
    } else if (cancel) {
        if (usedSwipeToDelete) {
            // hide delete button when canceling swipe-to-delete
            self.tableView.editing = NO;
        }
    } else {
        // remove attachments from list only
        NSAssert(self.collection, @"Need collection to remove attachments from");

        for (Attachment *attachment in self.attachmentsToDelete) {
            [self.collection removeAttachment:attachment];
        }
    }
    
    if (usedSwipeToDelete) {
        [[AppDelegate instance] saveDatabase];
    } else if (!cancel) {
        [self toggleEditMode:nil];
    }
    
    self.attachmentsToDelete = nil;
}

#pragma mark - Cell layout

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

- (UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.tableView.isEditing) {
        [self updateFooterButtons];
    } else if ([self.dataSource isContactSection:indexPath.section]) {
        Contact *contact = [self.dataSource contactAtIndexPath:indexPath];
        AudioAttachmentListViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AudioAttachmentListViewController"];
        viewController.contact = contact;
        [self.navigationController pushViewController:viewController animated:YES];
    } else {
        id<HXOPlaylist> playlist = [[HXOAudioAttachmentDataSourcePlaylist alloc] initWithDataSource:self.dataSource];
        
        // Get track number in original playlist (independent of search mode)
        NSUInteger trackNumber = [[self.dataSource indexPathForAttachment:[self.dataSource attachmentAtIndexPath:indexPath]] row];

        BOOL success = [[HXOAudioPlayer sharedInstance] playWithPlaylist:playlist atTrackNumber:trackNumber];
        
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

#pragma mark - Search Bar Delegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText isEqualToString:@""]) {
        self.dataSource.searchText = nil;
    } else {
        self.dataSource.searchText = searchText;
    }
}

#pragma mark - Search Display Delegate

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView {
    [tableView registerClass:[AudioAttachmentCell class] forCellReuseIdentifier:[AudioAttachmentCell reuseIdentifier]];
    [tableView registerClass:[ContactCell class] forCellReuseIdentifier:[ContactCell reuseIdentifier]];
    tableView.rowHeight = self.tableView.rowHeight;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    self.dataSource.searchText = nil;
}

#pragma mark - Audio Attachment Data Source Delegate

- (void)dataSourceWillChangeContent:(AudioAttachmentDataSource *)dataSource {
    [self.tableView beginUpdates];
}

- (void)dataSource:(AudioAttachmentDataSource *)dataSource didChangeAttachmentAtIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)dataSourceDidChangeContent:(AudioAttachmentDataSource *)dataSource {
    [self.tableView endUpdates];
}

- (void)dataSource:(AudioAttachmentDataSource *)dataSource commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forAttachment:(Attachment *)attachment {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self askToDeleteAttachments:@[ attachment ]];
    }
}

@end
