//
//  AudioAttachmentListViewController.m
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MediaAttachmentListViewController.h"

#import "AddToCollectionListViewController.h"
#import "AppDelegate.h"
#import "Attachment.h"
#import "MediaAttachmentCell.h"
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
#import "MediaBrowserDataSource.h"
#import "tab_attachments.h"
#import "ChatViewController.h"

#define FETCHED_RESULTS_DEBUG NO

@interface MediaAttachmentListViewController ()

@property (nonatomic, strong) UIView                         * footerContainerView;
@property (nonatomic, strong) MediaAttachmentDataSource      * dataSource;
@property (nonatomic, strong) NSArray                        * attachmentsToDelete;

@end


@implementation MediaAttachmentListViewController

@synthesize moviePlayerViewController = _moviePlayerViewController;
@synthesize imageViewController = _imageViewController;
@synthesize vcardViewController = _vcardViewController;
@synthesize interactionController = _interactionController;


#pragma mark - Lifecycle

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.tabBarItem.image = [[[tab_attachments alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self registerCellClass:[MediaAttachmentCell class]];
    [self updateDataSource];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self preferredContentSizeChanged:nil];
    
    self.tableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);


}

- (void) ensureSegmentedMediaTypeControl {
    if (_mediaTypeControl == nil) {
        self.mediaTypeControl = [[UISegmentedControl alloc] initWithItems:
                                 @[NSLocalizedString(@"attachment_type_visual", nil),
                                   NSLocalizedString(@"attachment_type_audios", nil),
                                   NSLocalizedString(@"attachment_type_other", nil)]];
        
        self.mediaTypeControl.selectedSegmentIndex = 0;
        [self.mediaTypeControl addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.mediaTypeControl;
    }
}

static NSArray * mediaTypesForSegment(NSInteger segment) {
    switch (segment) {
        case 0:
            return [Attachment visualMediaTypes];
            break;
        case 1:
            return [Attachment audioMediaTypes];
            break;
        case 2:
            return [Attachment otherMediaTypes];
            break;
        default:
            NSLog(@"Bad segment number: %ld", (long)segment);
            break;
    }
    return [Attachment allMediaTypes];
}


- (void) segmentChanged: (id) sender {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"AudioAttachmentListViewController:segmentChanged, sender= %@", sender);
    [self updateDataSource];
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
    BOOL isEditing = self.tableView.isEditing;
    NSString * editButtonTitle = NSLocalizedString(isEditing ? @"done" : @"edit_short", nil);
    UIBarButtonItemStyle editButtonStyle = isEditing ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
    UIBarButtonItem * editButton = [[UIBarButtonItem alloc] initWithTitle: editButtonTitle
                                                                    style: editButtonStyle
                                                                   target: self
                                                                   action: @selector(toggleEditMode:)];
    self.navigationItem.hidesBackButton = self.tableView.isEditing;
    self.mediaTypeControl.enabled = ! self.tableView.isEditing;
    self.mediaTypeControl.userInteractionEnabled = ! self.tableView.isEditing;

    // list of a collection
    if (self.collection) {
        self.navigationItem.title = self.collection.name;
        self.navigationItem.rightBarButtonItem = editButton;

    } else if (self.contact) {
        [self ensureSegmentedMediaTypeControl];
        self.navigationItem.title = self.contact.nickNameOrAlias;
    // list of all media items
    } else {
        [self ensureSegmentedMediaTypeControl];
        self.navigationItem.title = NSLocalizedString(@"audio_attachment_list_nav_title", nil);
        if (isEditing) {
            self.navigationItem.rightBarButtonItem = nil;
        } else {
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"collection_list_nav_title_short", nil) style: UIBarButtonItemStylePlain target: self action: @selector(showCollections:)];
        }
        self.navigationItem.leftBarButtonItem = editButton;
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
    } else {
        NSInteger selectedSegment = self.mediaTypeControl.selectedSegmentIndex;
        NSArray * mediaTypes = mediaTypesForSegment(selectedSegment);
        self.dataSource = [[MediaBrowserDataSource alloc] initWithContact:self.contact andMediaTypes:mediaTypes];
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

/*
"contact_message_count_format"                        = "%@ Nachrichten";
"contact_message_count_format (one)"                  = "%@ Nachricht";
"contact_audio_attachment_count_format"               = "%@ Dateien";
"contact_audio_attachment_count_format (one)"         = "%@ Datei";

*/
- (void) askToDeleteAttachments:(NSArray *)attachments {
    NSAssert(self.attachmentsToDelete == nil, @"AttachmentsToDelete not reset properly");

    NSArray * allToDelete = [self allAttachmentsWithSameMACSas:attachments];
    unsigned long duplicateCount = 0;
    NSString * duplicateCountString = @"";
    if (allToDelete.count < attachments.count) {
        self.attachmentsToDelete = attachments;
    } else {
        self.attachmentsToDelete = allToDelete;
        duplicateCount = allToDelete.count - attachments.count;
        if (duplicateCount > 0) {
            duplicateCountString = [NSString stringWithFormat:HXOPluralocalizedString(@"audio_attachment_list_count_attachment_duplicates", duplicateCount, NO), duplicateCount];
        }
    }
    
    unsigned long messageCount = 0;
    unsigned long attachmentCount = [self.attachmentsToDelete count];
    
    NSString *attachmentCountString = nil;
    NSString *actionSheetTitle = nil;

    for (Attachment * attachment in self.attachmentsToDelete) {
        if (attachment.message != nil) {
            messageCount++;
        }
    }
    
    attachmentCountString = [NSString stringWithFormat:HXOPluralocalizedString(@"audio_attachment_list_count_attachments", attachmentCount, NO), attachmentCount];
    
    if (messageCount == 0) {
        actionSheetTitle = [NSString stringWithFormat:NSLocalizedString(@"audio_attachment_list_confirm_delete_title", nil), attachmentCountString, duplicateCountString];
    } else {
        NSString * messageCountString = [NSString stringWithFormat:HXOPluralocalizedString(@"audio_attachment_list_count_messages", messageCount, NO), messageCount];
        actionSheetTitle = [NSString stringWithFormat:NSLocalizedString(@"audio_attachment_list_confirm_delete_more_title", nil), attachmentCountString, messageCountString,duplicateCountString];
    }
 
    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
    actionSheet.title = actionSheetTitle;

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
    NSArray *selectedAttachments = [self selectedAttachments];

    ContactPickerCompletion completion = ^(NSArray *contacts) {
        if (contacts != nil) {
            
            for (Attachment *attachment in selectedAttachments) {
                if (![AppDelegate.instance hasManagedObjectBeenDeleted:attachment] && !attachment.fileUnavailable) {
                    //[attachment protectFile];
                    for (Contact *contact in contacts) {
                        NSLog(@"Sending attachment %@ to %@", attachment.humanReadableFileName, contact.nickName);
                        [[[AppDelegate instance] chatBackend] sendMessage:@"" toContactOrGroup:contact toGroupMemberOnly:nil withAttachment:[attachment clone]];
                    }
                } else {
                    [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"attachment_not_available_message",nil) withTitle:NSLocalizedString(@"attachment_not_available_title",nil) withOKBlock:^{
                    }];
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

// return all attachments that are duplicates (have the same MAC) of the attachmentsToDelete
-(NSArray*)allAttachmentsWithSameMACSas:(NSArray*)attachmentsToDelete {
    NSMutableSet * macsToDelete = [NSMutableSet new];
    for (Attachment * attachment in attachmentsToDelete) {
        NSData * hmac = nil;
        if (attachment.sourceMAC != nil && attachment.sourceMAC.length>0) {
            hmac = attachment.sourceMAC;
        } else if (attachment.destinationMAC != nil && attachment.destinationMAC.length>0) {
            hmac = attachment.destinationMAC;
        }
        if (hmac != nil) {
            [macsToDelete addObject:hmac];
        }
    }
    
    // Not sure if we can make fetch requests with NSData as key, so we search them all
    NSManagedObjectContext *context = AppDelegate.instance.currentObjectContext;
    NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
    NSFetchRequest *fetchRequest = [NSFetchRequest new];
    [fetchRequest setEntity:entity];
    //NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"orderNumber" ascending:YES];
    //NSArray *sortDescriptors = @[sortDescriptor];
    //[fetchRequest setSortDescriptors:sortDescriptors];
    NSArray *attachments = [context executeFetchRequest:fetchRequest error:nil];
    NSMutableArray * sameAttachments = [NSMutableArray new];
    for (Attachment * attachment in attachments) {
        for (NSData * macToDelete in macsToDelete) {
            NSData * hmac = nil;
            if (attachment.sourceMAC != nil && attachment.sourceMAC.length>0) {
                hmac = attachment.sourceMAC;
            } else if (attachment.destinationMAC != nil && attachment.destinationMAC.length>0) {
                hmac = attachment.destinationMAC;
            }
            if (hmac != nil && [hmac isEqualToData:macToDelete]) {
                [sameAttachments addObject:attachment];
            }
        }
    }
    return sameAttachments;
}


#pragma mark - Action Sheet Delegate

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    BOOL usedSwipeToDelete = !self.tableView.allowsMultipleSelectionDuringEditing;
    BOOL delete = buttonIndex == actionSheet.destructiveButtonIndex;
    BOOL cancel = buttonIndex == actionSheet.cancelButtonIndex;

    if (delete) {
        
        // delete attachments
        for (Attachment *attachment in self.attachmentsToDelete) {
            if (attachment.message != nil) {
                [[AppDelegate instance] deleteObject:attachment.message];
            } else {
                NSURL * myURL = [NSURL URLWithString:attachment.localURL];
                if ([myURL isFileURL]) {
                    if ([Attachment deleteFileAtUrl:myURL]) {
                        attachment.ownedURL = nil;
                    }
                }
                [[AppDelegate instance] deleteObject:attachment];
            }
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
    UITableViewCell *prototypeCell = [self prototypeCellOfClass:[MediaAttachmentCell class]];
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
        MediaAttachmentListViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"MediaAttachmentListViewController"];
        viewController.contact = contact;
        [self.navigationController pushViewController:viewController animated:YES];
    } else {
        
        // Get track number in original playlist (independent of search mode)
        Attachment * selected = [self.dataSource attachmentAtIndexPath:indexPath];
        NSUInteger trackNumber = [[self.dataSource indexPathForAttachment:selected] row];
        NSLog(@"trackNumber = %lu selected = %@", (unsigned long)trackNumber, selected.humanReadableFileName);
        
        if ([selected.mediaType isEqualToString:@"audio"]) {
            
            id<HXOPlaylist> playlist = [[HXOAudioAttachmentDataSourcePlaylist alloc] initWithDataSource:self.dataSource];
            
            BOOL success = [[HXOAudioPlayer sharedInstance] playWithPlaylist:playlist atTrackNumber:trackNumber];
            
            if (success) {
                UIViewController *audioPlayerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"AudioPlayerViewController"];
                [self presentViewController:audioPlayerViewController animated:YES completion:NULL];
            } else {
                NSString * title;
                NSString * message;
                if (selected.fileUnavailable) {
                    title = NSLocalizedString(@"attachment_file_gone_title", nil);
                    message = NSLocalizedString(@"attachment_file_gone_message", nil);
                } else {
                    title = NSLocalizedString(@"attachment_cannot_play_title", nil);
                    message = NSLocalizedString(@"attachment_cannot_play_message", nil);
                }
                
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                                 message: message
                                                                delegate: nil
                                                       cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                       otherButtonTitles: nil];
                [alert show];
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
            }
        } else {
            [ChatViewController presentViewForAttachment:selected withDelegate:self];
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
    [tableView registerClass:[MediaAttachmentCell class] forCellReuseIdentifier:[MediaAttachmentCell reuseIdentifier]];
    [tableView registerClass:[ContactCell class] forCellReuseIdentifier:[ContactCell reuseIdentifier]];
    tableView.rowHeight = self.tableView.rowHeight;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    self.dataSource.searchText = nil;
}

#pragma mark - Audio Attachment Data Source Delegate

- (void)dataSourceWillChangeContent:(MediaAttachmentDataSource *)dataSource {
    [self.tableView beginUpdates];
}

- (void)dataSource:(MediaAttachmentDataSource *)dataSource didChangeAttachmentAtIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
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

- (void)dataSourceDidChangeContent:(MediaAttachmentDataSource *)dataSource {
    [self.tableView endUpdates];
}

- (void)dataSource:(MediaAttachmentDataSource *)dataSource commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forAttachment:(Attachment *)attachment {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self askToDeleteAttachments:@[ attachment ]];
    }
}

#pragma mark - AttachmentPresenterDelegate stuff


- (void) previewAttachment:(Attachment *)attachment {
    // NSLog(@"previewAttachment");
    if (attachment != nil && attachment.available) {
        NSURL * myURL = [attachment contentURL];
        NSString * uti = [Attachment UTIfromMimeType:attachment.mimeType];
        NSString * name = attachment.humanReadableFileName;
        NSLog(@"openWithInteractionController: uti=%@, name = %@ url = %@", uti, name, myURL);
        self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
        self.interactionController.delegate = self;
        self.interactionController.UTI = uti;
        self.interactionController.name = name;
        [self.interactionController presentPreviewAnimated:YES];
    }
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
    return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller
{
    return self.view;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller
{
    return self.view.frame;
}
- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
}

- (UIViewController*) thisViewController {
    return self;
}

- (ImageViewController*) imageViewController {
    if (_imageViewController == nil) {
        _imageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    }
    return _imageViewController;
}

- (ABUnknownPersonViewController*) vcardViewController {
    if (_vcardViewController == nil) {
        _vcardViewController = [[ABUnknownPersonViewController alloc] init];;
    }
    return _vcardViewController;
}

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonView didResolveToPerson:(ABRecordRef)person {
    [unknownPersonView dismissViewControllerAnimated:YES completion:nil];
}


@end
