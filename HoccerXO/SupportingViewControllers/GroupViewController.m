//
//  GroupViewController.m
//  HoccerXO
//
//  Created by David Siegel on 17.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupViewController.h"

#import "Group.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "UserDefaultsCells.h"
#import "GroupMemberCell.h"
#import "GroupMembership.h"
#import "InsetImageView.h"
#import "UserProfile.h"
#import "InviteGroupMemberViewController.h"


static const NSUInteger kHXOGroupUtilitySectionIndex = 1;

@interface FetchedResultsSectionAdapter : NSObject
{
    GroupViewController * _delegate; // TODO: make a proper delegate protocol
    NSUInteger _section;
}

- (id) initWithDelegate: (GroupViewController*) delegate sectionIndex: (NSUInteger) section;

@end


@interface GroupViewController ()
{
    BOOL _isNewGroup;
    ProfileItem * _inviteMemberItem;
}

@property (nonatomic,readonly) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,readonly) HXOTableViewCell           * groupMemberCell;

@end

@implementation GroupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setupNavigationButtons];
    _isNewGroup = self.group == nil;
    if (self.group == nil) {
        NSLog(@"creating new Group");
        self.group = [self.backend createGroup];
        [self setupContactKVO];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    if (_mode == ProfileViewModeNewGroup && ! self.isEditing) {
        [self setEditing: YES animated: YES];
    }
}

- (void) configureMode {
    if (self.group == nil) {
        _mode = ProfileViewModeNewGroup;
    } else { // TODO: if I'm admin...
        _mode = ProfileViewModeEditGroup;
    }
}

- (void) setGroup:(Group *)group {
    self.contact = group;
    _fetchedResultsController = nil;
}

- (Group*) group {
    if ([self.contact isKindOfClass: [Group class]]) {
        return (Group*) self.contact;
    }
    return nil;
}

- (id) getModelObject {
    return self.group;
}

- (NSString*) avatarDefaultImageName {
    return @"avatar_default_group"; // @"avatar_default_group_large";
}

- (NSString*) navigationItemTitleKey {
    switch (_mode) {
        case ProfileViewModeNewGroup:
            return @"navigation_title_new_group";
        case ProfileViewModeEditGroup:
        case ProfileViewModeShowGroup:
            return @"navigation_title_group";
        default:
            return @"navigation_title_unhandled_mode";
    }
}

- (NSString*) namePlaceholderKey {
    return @"group_name_placeholder";
}

- (void) setupNavigationButtons {
    if (_mode == ProfileViewModeNewGroup) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    } else if (_mode == ProfileViewModeEditGroup) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        if (self.isEditing) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        } else {
            self.navigationItem.leftBarButtonItem = nil;
        }
    } else {
        NSLog(@"setupNavigationButtons: unhandled mode %d", _mode);
    }
}

- (void) inviteMemberPressed: (id) sender {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: self.group.nickName style:UIBarButtonItemStylePlain target:nil action:nil];
    InviteGroupMemberViewController * controller = [self.storyboard instantiateViewControllerWithIdentifier:@"inviteGroupMemberViewController"];
    controller.group = self.group;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void) onEditingDone {
    if (_mode == ProfileViewModeNewGroup) {
        if (_canceled) {
            NSManagedObjectContext * moc = self.appDelegate.managedObjectContext;
            [moc deleteObject: self.group];
        }
        [self dismissViewControllerAnimated: YES completion: nil];
    }
}

- (HXOBackend*) backend {
    return ((AppDelegate*)UIApplication.sharedApplication.delegate).chatBackend;
}

- (NSArray*) populateItems {
    _inviteMemberItem = [[ProfileItem alloc] init];
    _inviteMemberItem.currentValue = NSLocalizedString(@"group_invite_button", nil);
    _inviteMemberItem.cellClass = [UserDefaultsCellDisclosure class];
    _inviteMemberItem.action = @selector(inviteMemberPressed:);
    _inviteMemberItem.target = self;
    _inviteMemberItem.alwaysShowDisclosure = YES;

    return [super populateItems];
}

- (void) configureEditOnlySections: (BOOL) editing {
    if (editing && ! self.isEditing) {
        [self.tableView deleteRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 0 inSection: kHXOGroupUtilitySectionIndex]] withRowAnimation: UITableViewRowAnimationFade];
        //[self.tableView deleteSections: [NSIndexSet indexSetWithIndex: kHXOGroupUtilitySectionIndex] withRowAnimation: UITableViewRowAnimationFade];
    } else if (!editing && self.isEditing) {
        //[self.tableView insertSections: [NSIndexSet indexSetWithIndex: kHXOGroupUtilitySectionIndex] withRowAnimation: UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 0 inSection: kHXOGroupUtilitySectionIndex]] withRowAnimation: UITableViewRowAnimationFade];

    }
}

- (NSArray*) composeItems: (NSArray*) items withEditFlag: (BOOL) editing {
    NSArray * utils = @[ @[_avatarItem], [self groupUtilities: editing], items];
    NSMutableArray * result = [[NSMutableArray alloc] initWithArray: utils];

    for (NSUInteger i = 0; i < self.fetchedResultsController.sections.count; ++i) {
        [result addObject: [[FetchedResultsSectionAdapter alloc] initWithDelegate: self sectionIndex: i]];
    }

    return result;
}

- (NSArray*) groupUtilities: (BOOL) editing {
    if (editing) {
        return @[_inviteMemberItem];
    }
    return @[_chatWithContactItem, _inviteMemberItem];
}

#pragma mark - Table View Delegate

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return _items.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_items[section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _items[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [GroupMembership class]]) {
        UITableViewCell * cell = [self prototypeCellOfClass: [GroupMemberCell class]];
        return cell.bounds.size.height;
    }
    return [super tableView: tableView heightForRowAtIndexPath: indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _items[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [GroupMembership class]]) {
        GroupMembership * membership = item;
        id contact = [self getContact: membership];
        GroupMemberCell * cell = (GroupMemberCell*)[self dequeueReusableCellOfClass: [GroupMemberCell class] forIndexPath: indexPath];
        // TODO: move to a configure method...
        cell.nickName.text = [contact nickName];
        UIImage * avatar = [contact avatarImage] != nil ? [contact avatarImage] : [UIImage imageNamed: @"avatar_default_contact"];
        cell.avatar.image = avatar;
        return cell;
    }
    return [super tableView: tableView cellForRowAtIndexPath: indexPath];
}

- (id) getContact: (GroupMembership*) membership {
    if (membership.contact != nil) {
        return membership.contact;
    }
    return [UserProfile sharedProfile];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_items[indexPath.section][indexPath.row] isKindOfClass: [GroupMembership class]]) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

#pragma mark - Fetched Results Controller

@synthesize fetchedResultsController = _fetchedResultsController;
- (NSFetchedResultsController*) fetchedResultsController {
    if (_fetchedResultsController == nil) {

        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName: [GroupMembership entityName] inManagedObjectContext:self.appDelegate.managedObjectContext];
        [fetchRequest setEntity:entity];

        // Set the batch size to a suitable number.
        [fetchRequest setFetchBatchSize:20];

        // performance: do not include subentities
        fetchRequest.includesSubentities = NO;

        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"contact.nickName" ascending: NO];
        NSArray *sortDescriptors = @[sortDescriptor];

        [fetchRequest setSortDescriptors:sortDescriptors];

        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.appDelegate.managedObjectContext sectionNameKeyPath:nil cacheName: nil];
        aFetchedResultsController.delegate = self;
        _fetchedResultsController = aFetchedResultsController;

        NSError *error = nil;
        if (![self.fetchedResultsController performFetch:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }

    }
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
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
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            // TODO:
            //[self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

@end


@implementation FetchedResultsSectionAdapter

- (id) initWithDelegate: (GroupViewController*) delegate sectionIndex: (NSUInteger) section {
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _section = section;
    }
    return self;
}

- (NSUInteger) count {
    return [_delegate.fetchedResultsController.sections[_section] numberOfObjects];
}

- (id) objectAtIndexedSubscript: (NSInteger) index {
    return [_delegate.fetchedResultsController objectAtIndexPath: [NSIndexPath indexPathForItem: index inSection: _section]];
}

@end
