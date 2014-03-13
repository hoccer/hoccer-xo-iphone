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
#import "UserProfile.h"
#import "GroupMemberInviteViewController.h"
#import "GroupAdminCell.h"

#define GROUPVIEW_DEBUG NO

// static const NSUInteger kHXOGroupUtilitySectionIndex = 1;

@interface FetchedResultsSectionAdapter : NSObject
{
    GroupViewController * _delegate; // TODO: make a proper delegate protocol
}

@property (nonatomic,readonly) NSString* name;
@property (nonatomic,readonly) BOOL managesOwnContent;

- (id) initWithDelegate: (GroupViewController*) delegate name: (NSString*) name;
- (NSUInteger) count;
- (id) objectAtIndexedSubscript: (NSInteger) index;

@end


@interface GroupViewController ()
{
    ProfileItem * _inviteMemberItem;
    ProfileItem * _joinGroupItem;
    ProfileItem * _declineInviteOrLeaveOrDeleteGroupItem;
    ProfileSection * _groupUtilitiesSection;

    ProfileItem * _adminsItem;
    //ProfileSection * _adminInfoSection;
    
    FetchedResultsSectionAdapter * _memberListItem;
    BOOL _deleteGroupFlag;
    BOOL _newGroupCreated;
}

@property (nonatomic,readonly) NSFetchedResultsController * fetchedResultsController;
@property (nonatomic,readonly) HXOTableViewCell           * groupMemberCell;

@end

@implementation GroupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"back_button_title", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setupNavigationButtons];
    _deleteGroupFlag = NO;
}

- (void) viewDidAppear:(BOOL)animated {
    _newGroupCreated = NO;
    if (_mode == ProfileViewModeNewGroup && ! self.isEditing) {
        [self setEditing: YES animated: YES];
    }
    if (self.group == nil) {
        [self.backend createGroupWithHandler:^(Group * group) {
            if (group) {
                self.group = group;
                [self setupContactKVO];
                _newGroupCreated = YES;
                [self cleanupGroup]; // in case the view was cancelled before group creation result was returned from server 
            }
        }];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: viewDidDisappear)");
    [self cleanupGroup];
}

- (void) cleanupGroup {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: cleanupGroup)");
    if (_deleteGroupFlag || (_newGroupCreated && _canceled)) {
        if ([self.group.groupState isEqualToString:@"kept"]) {
            [self.backend deleteInDatabaseAllMembersAndContactsofGroup:self.group];
            NSManagedObjectContext * moc = self.backend.delegate.managedObjectContext;
            [moc deleteObject: self.group];
            [self.appDelegate saveDatabase];
        } else {
            if (self.group.iAmAdmin) {
                [self.backend deleteGroup: self.group onDeletion:^(Group *group) {
                    if (group != nil) {
                        if (GROUPVIEW_DEBUG) NSLog(@"Successfully deleted group %@ from server", group.nickName);
                        _newGroupCreated = NO;
                    } else {
                        NSLog(@"ERROR: deleteGroup %@ failed, retrieving all groups", self.group);
                        [self.backend getGroupsForceAll:YES];
                    }
                }];
            } else {
                [self.backend leaveGroup: self.group onGroupLeft:^(Group *group) {
                    if (group != nil) {
                        if (GROUPVIEW_DEBUG) NSLog(@"Successfully left group %@", group.nickName);
                    } else {
                        NSLog(@"ERROR: leaveGroup %@ failed, retrieving all groups", self.group);
                        [self.backend getGroupsForceAll:YES];
                    }
                }];
            }
        }
        _deleteGroupFlag = NO;
    }    
}

- (void) configureMode {
    // XXX hack to detect modal presentation -> new groups
    UINavigationBar * navBar = self.navigationController.navigationBar;
    if (navBar.tag == 2342) {
        _mode = ProfileViewModeNewGroup;
    } else if ([self.group iAmAdmin]) {
        _mode = ProfileViewModeEditGroup;
    } else {
        _mode = ProfileViewModeShowGroup;
    }
}

- (void) setGroup:(Group *)group {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: setGroup)");
    self.contact = group;
    _fetchedResultsController = nil;
    [_profileDataSource updateModel: [self composeModel: self.isEditing]];
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
    return @"avatar_default_group_large";
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
    } else if (_mode == ProfileViewModeShowGroup) {
        self.navigationItem.rightBarButtonItem = nil;
        self.navigationItem.leftBarButtonItem = nil;
    } else {
        NSLog(@"setupNavigationButtons: unhandled mode %d", _mode);
    }
}

- (void) inviteMemberPressed: (id) sender {
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: self.group.nickName style:UIBarButtonItemStylePlain target:nil action:nil];
    GroupMemberInviteViewController * controller = [self.storyboard instantiateViewControllerWithIdentifier:@"inviteGroupMemberViewController"];
    controller.group = self.group;
    [self.navigationController pushViewController:controller animated:YES];
}

- (void) joinGroupPressed: (id) sender {
    if (GROUPVIEW_DEBUG) NSLog(@"Join Group pressed");
    [self.appDelegate.chatBackend joinGroup:self.group onJoined:^(Group *group) {
        if (GROUPVIEW_DEBUG) NSLog(@"Joined group %@", group);
    }];
}

- (void) declineOrLeaveOrDeletePressed: (id) sender {
    NSString * title = nil;
    NSString * destructiveButtonTitle = nil;
    if ([self.group.groupState isEqualToString:@"kept"]) {
        title = NSLocalizedString(@"group_delete_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"group_delete_button_title", nil);
    } else {
        if ([self.group.myGroupMembership.state isEqualToString: @"invited"]) {
            if (GROUPVIEW_DEBUG) NSLog(@"decline invitation");
            title = NSLocalizedString(@"group_decline_invitation_title", nil);
            destructiveButtonTitle = NSLocalizedString(@"group_decline_button_title", nil);
        } else {
            if (self.group.iAmAdmin) {
                title = NSLocalizedString(@"group_close_group_title", nil);
                destructiveButtonTitle = NSLocalizedString(@"group_close_group_button_title", nil);
                // otherButtonTitle = NSLocalizedString(@"group_close_and_keep_group_button_title", nil);
            } else {
                title = NSLocalizedString(@"group_leave_group_title", nil);
                destructiveButtonTitle = NSLocalizedString(@"group_leave_group_button_title", nil);
            }
        }
    }
    UIActionSheet * actionSheet = [[UIActionSheet alloc] initWithTitle: title
                                                              delegate: self
                                                     cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                                destructiveButtonTitle: destructiveButtonTitle
                                                     otherButtonTitles: nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [actionSheet showInView: self.view];
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSLog(@"actionSheet: clickedButtonAtIndex %d",buttonIndex);
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: set flag to destroy group");
        _deleteGroupFlag = YES;
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void) onEditingDone {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: onEditingDone");
    if (_mode == ProfileViewModeNewGroup) {
        if (_canceled) {
            // XXX: workaround for #276
            // TODO: clean-up group handling and replace this mess with something sane.
            if (self.group) {
                NSManagedObjectContext * moc = self.appDelegate.managedObjectContext;
                [moc deleteObject: self.group];
            }
        } else {
            // update group on server
            [self.appDelegate.chatBackend updateGroup: self.group];
        }
        [self dismissViewControllerAnimated: YES completion: nil];
    } else if (_mode == ProfileViewModeEditGroup) {
        if (!_canceled) {
            [self.appDelegate.chatBackend updateGroup: self.group];
        }
    }
}

- (HXOBackend*) backend {
    return ((AppDelegate*)UIApplication.sharedApplication.delegate).chatBackend;
}

- (void) populateItems {
    _inviteMemberItem = [[ProfileItem alloc] initWithName:@"InviteGroupMemberItem"];
    _inviteMemberItem.editLabel = NSLocalizedString(@"group_invite_button", nil);
    _inviteMemberItem.cellClass = [UserDefaultsCellDisclosure class];
    _inviteMemberItem.action = @selector(inviteMemberPressed:);
    _inviteMemberItem.target = self;
    _inviteMemberItem.alwaysShowDisclosure = YES;

    _joinGroupItem = [[ProfileItem alloc] initWithName:@"JoinGroupItem"];
    _joinGroupItem.editLabel = NSLocalizedString(@"group_join_button", nil);
    _joinGroupItem.cellClass = [UserDefaultsCellDisclosure class];
    _joinGroupItem.action = @selector(joinGroupPressed:);
    _joinGroupItem.target = self;

    _declineInviteOrLeaveOrDeleteGroupItem = [[ProfileItem alloc] initWithName:@"DeclineInviteOrLeaveGroupItem"];
    _declineInviteOrLeaveOrDeleteGroupItem.editLabel = [self declineOrLeaveOrDeleteLabel];
    _declineInviteOrLeaveOrDeleteGroupItem.cellClass = [UserDefaultsCellDisclosure class];
    _declineInviteOrLeaveOrDeleteGroupItem.action = @selector(declineOrLeaveOrDeletePressed:);
    _declineInviteOrLeaveOrDeleteGroupItem.target = self;

    _groupUtilitiesSection = [ProfileSection sectionWithName:@"GroupUtilitiesSection" items: nil];

    _adminsItem = [[ProfileItem alloc] initWithName:@"GroupAdminsItem"];
    _adminsItem.currentValue = [self adminsLabelText];
    _adminsItem.cellClass = [GroupAdminCell class];

    //_adminInfoSection = [ProfileSection sectionWithName:@"AdminInfoSection" items: _adminsItem, nil];

    _memberListItem = [[FetchedResultsSectionAdapter alloc] initWithDelegate: self name: @"GroupMemberSection"];

    [super populateItems];
}

- (NSString*) nickNameIconName {
    return @"icon_profile-group";
}

- (NSString*) declineOrLeaveOrDeleteLabel {
    if ([self.group.groupState isEqualToString:@"kept"]) {
        return NSLocalizedString(@"group_delete_data", nil);
    }
    if ([self.group.myGroupMembership.state isEqualToString: @"invited"]) {
        return NSLocalizedString(@"group_decline_invitation", nil);
    } else {
        if (self.group.iAmAdmin) {
            return NSLocalizedString(@"group_close", nil);
        } else {
            return NSLocalizedString(@"group_leave", nil);
        }
    }
}

- (void) populateValues {
    _adminsItem.currentValue = [self adminsLabelText];
    [super populateValues];
}

- (NSString*) adminsLabelText {
    NSMutableArray * admins = [[NSMutableArray alloc] init];
    if (self.group.iAmAdmin) {
        [admins addObject: NSLocalizedString(@"group_admin_you", nil)];
    }
    [self.group.members enumerateObjectsUsingBlock:^(GroupMembership* member, BOOL *stop) {
        if ([member.role isEqualToString: @"admin"] && ! [member.contact isEqual: self.group]) {
            if (member.contact.nickName != nil) {
                [admins addObject: member.contact.nickName];
            } else {
                [admins addObject: @"?"];
            }
        }
    }];
    if (admins.count == 0) {
        return @"No Admin";
    }
    NSString * label = NSLocalizedString(admins.count > 1 ? @"group_admin_label_plural" : @"group_admin_label_singular", nil);
    return [label stringByAppendingString: [admins componentsJoinedByString:@", "]];
}

- (NSArray*) composeModel: (BOOL) editing {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: composeItems");
    //[self composeProfileItems: editing];
    if (editing) {
        return @[ _coreSection/*, _profileItemsSection, _adminInfoSection*/, _memberListItem];
    }
    return @[ _coreSection, [self groupUtilities]/*, _profileItemsSection, _adminInfoSection*/, _memberListItem];
}

- (NSUInteger) groupMemberSectionIndex {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: groupMemberSectionIndex");
    return [_profileDataSource indexOfSection: _memberListItem];
}

- (ProfileSection*) groupUtilities {
    NSMutableArray * utilities = [[NSMutableArray alloc] init];
    if ([self.group.myGroupMembership.state isEqualToString:@"joined"]) {
        [utilities addObject: _chatWithContactItem];
    } else if ([self.group.myGroupMembership.state isEqualToString: @"invited"]) {
        [utilities addObject: _joinGroupItem];
    } else {
        NSLog(@"unhandled state - membership: %@ state: %@", self.group.myGroupMembership, self.group.myGroupMembership.state);
    }
    
    _declineInviteOrLeaveOrDeleteGroupItem.currentValue = [self declineOrLeaveOrDeleteLabel];
    if (![self.group.groupState isEqualToString:@"kept"]) {
        if ( ! [self.group iAmAdmin]) {
            [utilities addObject: _declineInviteOrLeaveOrDeleteGroupItem];
        } else {
            [utilities addObject: _inviteMemberItem];
            [utilities addObject: _declineInviteOrLeaveOrDeleteGroupItem];
            
        }
    } else {
        [utilities addObject: _declineInviteOrLeaveOrDeleteGroupItem];
    }
    _groupUtilitiesSection = [ProfileSection sectionWithName: @"GroupUtilitySection" array: utilities];
    return _groupUtilitiesSection;
}

#pragma mark - Table View Delegate


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: heightForRowAtIndexPath");
    id item = _profileDataSource[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [GroupMembership class]]) {
        UITableViewCell * cell = [self prototypeCellOfClass: [GroupMemberCell class]];
        return cell.bounds.size.height;
    }
    return [super tableView: tableView heightForRowAtIndexPath: indexPath];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: cellForRowAtIndexPath %@",indexPath);
    id item = _profileDataSource[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [GroupMembership class]]) {
        GroupMemberCell * cell = (GroupMemberCell*)[self dequeueReusableCellOfClass: [GroupMemberCell class] forIndexPath: indexPath];
        [self configureMembershipCell: cell atIndexPath: indexPath];
        return cell;
    }
    return [super tableView: tableView cellForRowAtIndexPath: indexPath];
}


- (id) getContact: (GroupMembership*) membership {
    if (![self.group isEqual:membership.contact]) {
        return membership.contact;
    }
    return [UserProfile sharedProfile];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: heightForHeaderInSection %d",section);
    return section == [self groupMemberSectionIndex] ? 24 : [super tableView: tableView heightForHeaderInSection: section];
}

- (UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == [self groupMemberSectionIndex]) {
        UILabel * adminHeader = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, 24)];
        adminHeader.font = [UIFont systemFontOfSize: 12];
        adminHeader.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
        adminHeader.text = [self adminsLabelText];
        adminHeader.textAlignment = NSTextAlignmentCenter;
        return adminHeader;
    }
    return [super tableView: tableView viewForHeaderInSection: section];
/*
    
    
    
    
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: viewForHeaderInSection %d",section);
    if (section != [self groupMemberSectionIndex]) {
        return nil;
    }
    UIView * header = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.view.frame.size.width, 5)];
    header.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed:@"group_member_divider"]];
    return header;
 */
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: willSelectRowAtIndexPath %@",indexPath);
    id item = _profileDataSource[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [GroupMembership class]]) {
        return indexPath;
    }
    return [super tableView: tableView willSelectRowAtIndexPath: indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: didSelectRowAtIndexPath %@",indexPath);
    if (indexPath.section == [self groupMemberSectionIndex]) {
        GroupMembership * member = (GroupMembership*)_profileDataSource[indexPath.section][indexPath.row];
        ProfileViewController * controller = [self.storyboard instantiateViewControllerWithIdentifier:@"profileViewController"];
        controller.contact = [member.contact isEqual: self.group] ? nil : member.contact;
        [self.navigationController pushViewController: controller animated: YES];
    } else {
        [super tableView: tableView didSelectRowAtIndexPath: indexPath];
    }
}

#pragma mark - Fetched Results Controller

@synthesize fetchedResultsController = _fetchedResultsController;
- (NSFetchedResultsController*) fetchedResultsController {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: fetchedResultsController");
    if (_fetchedResultsController == nil && self.group != nil) {
        if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: new fetchedResultsController");

        NSDictionary * vars = @{ @"group" : self.group };
        NSFetchRequest *fetchRequest = [self.appDelegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupMembershipsByGroup" substitutionVariables: vars];

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
        if (![_fetchedResultsController performFetch:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }

    }
    return _fetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    if (GROUPVIEW_DEBUG) NSLog(@"controllerWillChangeContent");
    if (GROUPVIEW_DEBUG) NSLog(@"%@",[NSThread callStackSymbols]);
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (GROUPVIEW_DEBUG) NSLog(@"didChangeSection %@ atIndex %d forType %d", sectionInfo,sectionIndex,type);
    switch(type) {
        case NSFetchedResultsChangeInsert:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeInsert sectionIndex %d", sectionIndex);
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeDelete sectionIndex %d", sectionIndex);
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    // NSLog(@"didChangeObject %@ atIndexPath %@ forType %d newIndexPath %@", anObject,indexPath,type,newIndexPath);
    if (GROUPVIEW_DEBUG) NSLog(@"didChangeObject atIndexPath %@ forType %d newIndexPath %@",indexPath,type,newIndexPath);
    UITableView *tableView = self.tableView;

    indexPath = [NSIndexPath indexPathForItem: indexPath.row inSection:indexPath.section + [self groupMemberSectionIndex]];
    newIndexPath = [NSIndexPath indexPathForItem: newIndexPath.row inSection:newIndexPath.section + [self groupMemberSectionIndex]];
    // NSLog(@"didChangeObject(2) %@ atIndexPath %@ forType %d newIndexPath %@", anObject,indexPath,type,newIndexPath);
    if (GROUPVIEW_DEBUG) NSLog(@"didChangeObject(2) atIndexPath %@ forType %d newIndexPath %@",indexPath,type,newIndexPath);

    switch(type) {
        case NSFetchedResultsChangeInsert:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeInsert newIndexPath %@", newIndexPath);
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeDelete indexPath %@", indexPath);
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeUpdate indexPath %@", indexPath);
            //[self configureMembershipCell:(GroupMemberCell*)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeMove:
            if (GROUPVIEW_DEBUG) NSLog(@"NSFetchedResultsChangeMove indexPath %@ newIndexPath %@", indexPath,newIndexPath);
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    if (GROUPVIEW_DEBUG)  NSLog(@"controllerDidChangeContent");
    if (GROUPVIEW_DEBUG) NSLog(@"%@",[NSThread callStackSymbols]);
    [self.tableView endUpdates];
    // TODO: don't update everything everytime - be a little more selective
    [self populateValues];
    [_profileDataSource updateModel: [self composeModel: self.isEditing]];
    if (GROUPVIEW_DEBUG) NSLog(@"controllerDidChangeContent ready");
}

- (void) configureMembershipCell: (GroupMemberCell*) cell atIndexPath: (NSIndexPath*) indexPath {
    if (GROUPVIEW_DEBUG) NSLog(@"GroupViewController: configureMembershipCell atIndexPath %@",indexPath);
    GroupMembership * membership = _profileDataSource[indexPath.section][indexPath.row];
    id contact = [self getContact: membership];
    // TODO: move to a configure method...
    cell.nickName.text = [contact nickName];
    if ([membership.state isEqualToString: @"invited"]) {
        cell.nickName.alpha = 0.5;
    } else {
        cell.nickName.alpha = 1.0;
    }
    NSString * membershipStateKey = [NSString stringWithFormat: @"membership_state_%@", membership.state];
    NSString * membershipRoleKey = [NSString stringWithFormat: @"membership_role_%@", membership.role];
    cell.statusLabel.text = [NSString stringWithFormat:@"%@ - %@", NSLocalizedString(membershipRoleKey, nil), NSLocalizedString(membershipStateKey, nil)];
    UIImage * avatar = [contact avatarImage] != nil ? [contact avatarImage] : [UIImage imageNamed: @"avatar_default_contact"];
    cell.avatar.image = avatar;
}
@end


@implementation FetchedResultsSectionAdapter

@synthesize name = _name;

- (id) initWithDelegate: (GroupViewController*) delegate name: (NSString*) theName {
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _name = theName;
    }
    return self;
}

- (NSUInteger) count {
    if (GROUPVIEW_DEBUG) NSLog(@"FetchedResultsSectionAdapter: FetchedResultsSectionAdapter count");
    return [_delegate.fetchedResultsController.sections[0] numberOfObjects];
}

- (id) objectAtIndexedSubscript: (NSInteger) index {
    if (GROUPVIEW_DEBUG) NSLog(@"FetchedResultsSectionAdapter: objectAtIndexedSubscript %d",index);
    return [_delegate.fetchedResultsController objectAtIndexPath: [NSIndexPath indexPathForItem: index inSection: 0]];
}

- (BOOL) managesOwnContent {
    return YES;
}

@end
