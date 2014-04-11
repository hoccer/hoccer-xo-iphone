//
//  ContactSheet.m
//  HoccerXO
//
//  Created by David Siegel on 31.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetController.h"

#import "Contact.h"
#import "Group.h"
#import "ChatViewController.h"
#import "HXOUserDefaults.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "AvatarView.h"
#import "HXOUI.h"
#import "avatar_contact.h"
#import "avatar_group.h"
#import "GroupMembership.h"
#import "SmallContactCell.h"
#import "DatasheetViewController.h"
#import "UserProfile.h"
#import "ContactPicker.h"


//#define SHOW_CONNECTION_STATUS
//#define SHOW_UNREAD_MESSAGE_COUNT

static const BOOL GROUPVIEW_DEBUG    = NO;
static const BOOL RELATIONSHIP_DEBUG = NO;

@interface ContactSheetController ()

@property (nonatomic, readonly) DatasheetItem              * chatItem;
@property (nonatomic, readonly) DatasheetItem              * blockContactItem;
@property (nonatomic, readonly) Contact                    * contact;
@property (nonatomic, readonly) Group                      * group;

@property (nonatomic, readonly) DatasheetSection           * invitationResponseSection;
@property (nonatomic, readonly) DatasheetItem              * joinGroupItem;
@property (nonatomic, readonly) DatasheetItem              * invitationDeclineItem;

@property (nonatomic, readonly) DatasheetSection           * groupMemberSection;
@property (nonatomic, strong)   NSMutableArray             * groupMemberItems;

@property (nonatomic, readonly) DatasheetItem              * inviteMembersItem;

@property (nonatomic, readonly) HXOBackend                 * chatBackend;
@property (nonatomic, readonly) AppDelegate                * appDelegate;

@property (nonatomic, strong)   NSFetchedResultsController * fetchedResultsController;
@property (nonatomic, readonly) NSManagedObjectContext     * managedObjectContext;

@property (nonatomic, strong)   id                           profileObserver;

@end

@implementation ContactSheetController

@synthesize chatItem = _chatItem;
@synthesize blockContactItem = _blockContactItem;
@synthesize chatBackend = _chatBackend;
@synthesize groupMemberSection = _groupMemberSection;

- (void) commonInit {
    [super commonInit];

    self.groupMemberItems = [NSMutableArray array];

    self.nicknameItem.valuePlaceholder = nil;

    self.avatarItem.dependencyPaths = @[@"relationshipState"
#ifdef SHOW_CONNECTION_STATUS
                                        , @"connectionStatus"
#endif
#ifdef SHOW_UNREAD_MESSAGE_COUNT
                                        , @"unreadMessages.@count"
#endif
                                        ];

    self.keyItem.visibilityMask = DatasheetModeView;
    self.keyItem.dependencyPaths = @[@"verifiedKey"];

    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(deleteContactPressed:);

    self.destructiveSection.items = @[self.blockContactItem, self.destructiveButton];
}

- (BOOL) isEditable {
    return ! self.group || ! [self.group.myGroupMembership.state isEqualToString: @"invited"];
}

- (void) registerCellClasses: (DatasheetViewController*) viewController {
    [super registerCellClasses: viewController];
    [viewController registerCellClass: [SmallContactCell class]];
}

- (void) addUtilitySections:(NSMutableArray *)sections {
    [super addUtilitySections: sections];
    [sections addObject: self.invitationResponseSection];
    [sections addObject: self.groupMemberSection];
}

- (Contact*) contact {
    if ([self.inspectedObject isKindOfClass: [Contact class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (Group*) group {
    if([self.inspectedObject isKindOfClass: [Group class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (NSString*) title {
    return self.group ? @"navigation_title_group" :  @"navigation_title_contact";
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.chatItem, self.keyItem];
    return section;
}

- (DatasheetItem*) chatItem {
    if ( ! _chatItem) {
        _chatItem = [self itemWithIdentifier: @"chat_with_contact" cellIdentifier: @"DatasheetKeyValueCell"];
        _chatItem.dependencyPaths = @[@"messages.@count"];
        //_chatItem.visibilityMask = DatasheetModeView;
        _chatItem.accessoryStyle = DatasheetAccessoryDisclosure;
    }
    return _chatItem;
}

- (DatasheetItem*) blockContactItem {
    if ( ! _blockContactItem) {
        _blockContactItem = [self itemWithIdentifier: @"block_contact" cellIdentifier: @"DatasheetActionCell"];
        _blockContactItem.dependencyPaths = @[@"relationshipState", kHXONickName];
        _blockContactItem.visibilityMask = DatasheetModeEdit;
        _blockContactItem.target = self;
        _blockContactItem.action = @selector(blockToggled:);
    }
    return _blockContactItem;
}

- (id) valueForItem: (DatasheetItem*) item {
    if ([item isEqual: self.chatItem]) {
        return @(self.contact.messages.count);
    } else if ([item isEqual: self.keyItem]) {
        return [self keyItemTitle];
    }
    return [super valueForItem: item];
}


- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.blockContactItem]) {
        return (self.contact.isBlocked || self.contact.isFriend) && [super isItemVisible:item];
    } else if ([item isEqual: self.keyItem]) {
        return ! self.group && [super isItemVisible: item];
    } else if ([item isEqual: self.inviteMembersItem]) {
        return self.group.iAmAdmin && [super isItemVisible: item];
    } else if ([item isEqual: self.joinGroupItem] || [item isEqual: self.invitationDeclineItem]) {
        return [self.group.myGroupMembership.state isEqualToString: @"invited"];
    }
    return [super isItemVisible: item];
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    if ([item isEqual: self.nicknameItem]) {
        return self.group.iAmAdmin && [super isItemEnabled: item];
    } else if ([item isEqual: self.avatarItem]) {
        return self.group.iAmAdmin;
    }

    return [super isItemEnabled: item];
}

- (BOOL) isItemDeletable:(DatasheetItem *)item {
    int index = [self.groupMemberItems indexOfObject: item];
    return self.group.iAmAdmin && index != NSNotFound && ! [[self contactAtIndex: index] isEqual: self.group];
}

- (NSString*) valueFormatStringForItem:(DatasheetItem *)item {
    if ([item isEqual: self.chatItem]) {
        return self.contact.messages.count == 1 ? @"message_count_format_singular" : @"message_count_format_plural";
    }
    return nil;
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
    [super didChangeValueForItem: item];
    if ([item isEqual: self.avatarItem]) {
        self.avatarView.isBlocked = self.contact.isBlocked;
        if ( ! self.contact.avatarImage) {
            // a liitle extra somethin for those without avatars ;)
            self.avatarView.isOnline = self.contact.isOnline;
            self.avatarView.badgeText = [HXOUI messageCountBadgeText: self.contact.unreadMessages.count];
        } else {
            self.avatarView.isOnline = NO;
            self.avatarView.badgeText = nil;
        }
    }
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.blockContactItem]) {
        return [self blockItemTitle];
    } else if ([item isEqual: self.destructiveButton]) {
        return [self destructiveButtonTitle];
    } else if ([item isEqual: self.inviteMembersItem]) {
        return NSLocalizedString(@"group_invite_members_title", nil);
    }
    return nil;
}

- (NSString*) valuePlaceholderForItem:(DatasheetItem *)item {
    if ([item isEqual: self.nicknameItem]) {
        return  NSLocalizedString( self.group ? @"group_name_placeholder" : @"profile_name_placeholder", nil);
    }
    return [super valuePlaceholderForItem: item];
}

- (NSString*) segueIdentifierForItem:(DatasheetItem *)item {
    int groupMemeberIndex = [self.groupMemberItems indexOfObject: item];
    if (groupMemeberIndex != NSNotFound) {
        return [self groupMemberSegueIdentifier: groupMemeberIndex];
    } else if ([item isEqual: self.chatItem]) {
        return [self chatItemSegueIdentifier];
    }
    return nil;
}

- (NSString*) deleteButtonTitleForItem:(DatasheetItem *)item {
    return [self.groupMemberItems indexOfObject: item] != NSNotFound ? NSLocalizedString(@"group_kick_member_confirm", nil) : nil;
}

- (NSString*) keyItemTitle {
    NSString * titleKey;
    if (self.contact.verifiedKey == nil) {
        titleKey = @"unverified_key_title";
    } else if ([self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        titleKey = @"verified_key_title";
    } else {
        titleKey = @"untrusted_key_title";
    }
    return NSLocalizedString(titleKey, nil);
}

- (NSString*) destructiveButtonTitle {
    if (self.group) {
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
    } else {
        return @"delete_contact";
    }
}

- (NSString*) chatItemSegueIdentifier {
    DatasheetViewController * vc = (DatasheetViewController*)self.delegate; // XXX hack

    UIViewController * parent = vc.navigationController.viewControllers.count > 1 ? vc.navigationController.viewControllers[vc.navigationController.viewControllers.count - 2] : nil;
    if ([parent respondsToSelector: @selector(unwindToChatView:)] &&
        [[(id)parent inspectedObject] isEqual: self.contact])
    {
        return @"unwindToChat";
    } else {
        return @"showChat";
    }
}

- (void) inspectedObjectWillChange {
    [super inspectedObjectWillChange];
    [self removeProfileObservers];
    if (self.fetchedResultsController) {
        self.fetchedResultsController.delegate = nil;
        self.fetchedResultsController = nil;
    }
    [self.groupMemberItems removeAllObjects];
}

- (void) inspectedObjectDidChange {
    self.fetchedResultsController = [self createFetchedResutsController];
    if (self.fetchedResultsController) {
        for (int i = 0; i < [self.fetchedResultsController.sections[0] numberOfObjects]; ++i) {
            [self.groupMemberItems addObject: [self groupMemberItem: i]];
        }
    }
    [self addProfileObservers];

    self.avatarView.defaultIcon = self.group ? [[avatar_group alloc] init] : [[avatar_contact alloc] init];
    self.backButtonTitle = self.contact.nickName;
    [super inspectedObjectDidChange];
}


#pragma mark - UI Actions

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    [super prepareForSegue: segue withItem: item sender: sender];
    if ([segue.identifier isEqualToString: @"showContact"]) {
        DatasheetViewController * contactView = segue.destinationViewController;
        contactView.inspectedObject = [self contactForItem: item];
    } else if ([segue.identifier isEqualToString: @"showChat"]) {
        ChatViewController * chatView = segue.destinationViewController;
        chatView.inspectedObject = self.contact;
    }
}


#pragma mark - Block Contact


- (NSString*) blockItemTitle {
    NSString * formatKey = nil;
    if (self.contact.isFriend) {
        formatKey = @"contact_block";
    } else if (self.contact.isBlocked) {
        formatKey = @"contact_unblock";
    }
    return formatKey ? [NSString stringWithFormat: NSLocalizedString(formatKey, nil), self.nicknameItem.currentValue] : nil;
}

- (void) blockToggled: (id) sender {
    if (self.contact.isFriend) {
        // NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if (self.contact.isBlocked) {
        // NSLog(@"blocked -> friend");
        [self.chatBackend unblockClient: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"unblockClient: %@", success ? @"success" : @"failed");
        }];
    } else {
        NSLog(@"ContactSheetController toggleBlockedPressed: unhandled status %@", self.contact.status);
    }
}

#pragma mark - Destructive Button

- (void) destructiveButtonPressed: (UIViewController*) sender {
    NSString * title = nil;
    NSString * destructiveButtonTitle = nil;
    SEL        destructor;

    if ([self.group.groupState isEqualToString:@"kept"]) {
        title = NSLocalizedString(@"group_delete_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"group_delete_button_title", nil);
        destructor = @selector(deleteGroupData);
    } else if (self.group.iAmAdmin) {
        title = NSLocalizedString(@"group_close_group_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"group_close_group_button_title", nil);
        destructor = @selector(deleteGroup);
    } else if (self.group) {
        title = NSLocalizedString(@"group_leave_group_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"group_leave_group_button_title", nil);
        destructor = @selector(leaveGroup);
    } else {
        title = NSLocalizedString(@"delete_contact_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"Delete", nil);
        destructor = @selector(deleteContact);
    }

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            IMP imp = [self methodForSelector: destructor];
            void (*func)(id, SEL, id) = (void *)imp;
            func(self, destructor, self);
        }
    };
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"delete_contact_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete_contact_confirm", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: [(id)self.delegate view]];
}

- (void) deleteGroupData {
    [self.chatBackend deleteInDatabaseAllMembersAndContactsofGroup: self.group];
    NSManagedObjectContext * moc = self.chatBackend.delegate.managedObjectContext;
    [moc deleteObject: self.group];
    [self.appDelegate saveDatabase];
}

- (void) deleteGroup {
    [self.chatBackend deleteGroup: self.group onDeletion:^(Group *group) {
        if (group != nil) {
            if (GROUPVIEW_DEBUG) NSLog(@"Successfully deleted group %@ from server", group.nickName);
        } else {
            NSLog(@"ERROR: deleteGroup %@ failed, retrieving all groups", self.group);
            [self.chatBackend getGroupsForceAll: YES];
        }
    }];
}

- (void) leaveGroup {
    [self.chatBackend leaveGroup: self.group onGroupLeft:^(Group *group) {
        if (group != nil) {
            if (GROUPVIEW_DEBUG) NSLog(@"Successfully left group %@", group.nickName);
        } else {
            NSLog(@"ERROR: leaveGroup %@ failed, retrieving all groups", self.group);
            [self.chatBackend getGroupsForceAll:YES];
        }
    }];
}

- (void) deleteContact {
    NSLog(@"deleting contact with relationshipState %@", self.contact.relationshipState);
    if ([self.contact.relationshipState isEqualToString:@"groupfriend"] || [self.contact.relationshipState isEqualToString:@"kept"]) {
        [self.chatBackend handleDeletionOfContact: self.contact];
    } else {
        [self.chatBackend depairClient: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        }];
    }
}

#pragma mark - Invitation Response Section

@synthesize invitationResponseSection = _invitationResponseSection;
- (DatasheetSection*) invitationResponseSection {
    if ( ! _invitationResponseSection) {
        _invitationResponseSection = [DatasheetSection datasheetSectionWithIdentifier: @"invitation_response_section"];
        _invitationResponseSection.title = [[NSAttributedString alloc] initWithString: @"Du bist eingeladen der gruppe beizutreten" attributes: nil];
        [_invitationResponseSection setItems: @[self.joinGroupItem, self.invitationDeclineItem]];
    }
    return _invitationResponseSection;
}

@synthesize joinGroupItem = _joinGroupItem;
- (DatasheetItem*) joinGroupItem {
    if ( ! _joinGroupItem) {
        _joinGroupItem = [self itemWithIdentifier: @"invitation_accept" cellIdentifier: @"DatasheetActionCell"];
        _joinGroupItem.title = NSLocalizedString(@"group_join_button", nil);
        _joinGroupItem.target = self;
        _joinGroupItem.action = @selector(joinGroupTapped:);
    }
    return _joinGroupItem;
}

@synthesize invitationDeclineItem = _invitationDeclineItem;
- (DatasheetItem*) invitationDeclineItem {
    if ( ! _invitationDeclineItem) {
        _invitationDeclineItem = [self itemWithIdentifier: @"" cellIdentifier: @"DatasheetActionCell"];
        _invitationDeclineItem.title = NSLocalizedString( @"group_decline_invitation", nil);
        _invitationDeclineItem.target = self;
        _invitationDeclineItem.action = @selector(declineInvitationTapped:);
    }
    return _invitationDeclineItem;
}

- (void) joinGroupTapped: (id) sender {
    [self.chatBackend joinGroup: self.group onJoined:^(Group *group) {
        if (GROUPVIEW_DEBUG) NSLog(@"Joined group %@", group);
    }];
}

- (void) declineInvitationTapped: (id) sender {
    NSString * title = NSLocalizedString(@"group_decline_invitation_title", nil);
    NSString * destructiveButtonTitle = NSLocalizedString(@"group_decline_button_title", nil);

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self leaveGroup];
        }
    };
    UIActionSheet * actionSheet = [HXOUI actionSheetWithTitle: title
                                              completionBlock: completion
                                            cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                       destructiveButtonTitle: destructiveButtonTitle
                                            otherButtonTitles: nil];
    [actionSheet showInView: [(id)self.delegate view]];
}

#pragma mark - Group Member Section

- (Contact*) contactForItem: (DatasheetItem*) groupMemberItem {
    NSInteger index = [self.groupMemberItems indexOfObject: groupMemberItem];
    if (index != NSNotFound) {
        return [self contactAtIndex: index];
    }
    return nil;
}

- (Contact*) contactAtIndex: (NSUInteger) index {
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: index inSection: 0];
    return [self.fetchedResultsController objectAtIndexPath: indexPath];
}

- (DatasheetItem*) myMembershipItem {
    if (self.group) {
        NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: self.group];
        return self.groupMemberItems[indexPath.row];
    }
    return nil;
}

- (NSAttributedString*) groupMemberSectionTitle {
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
    NSString * title;
    if (admins.count == 0) {
        title = NSLocalizedString(@"group_no_admin", nil);
    } else {
        NSString * label = NSLocalizedString(admins.count > 1 ? @"group_admin_label_plural" : @"group_admin_label_singular", nil);
        title = [label stringByAppendingString: [admins componentsJoinedByString:@", "]];
    }
    return [[NSAttributedString alloc] initWithString: title attributes: nil];
}


- (DatasheetSection*) groupMemberSection {
    if ( ! _groupMemberSection) {
        _groupMemberSection = [DatasheetSection datasheetSectionWithIdentifier: @"group_member_section"];
        _groupMemberSection.delegate = self;
    }
    return _groupMemberSection;
}

- (NSUInteger) numberOfItemsInSection:(DatasheetSection *)section {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return self.groupMemberItems.count + (self.group.iAmAdmin ? 1 : 0);
    }
    return 0;
}

- (DatasheetItem*) section:(DatasheetSection *)section itemAtIndex:(NSUInteger)index {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return index < self.groupMemberItems.count ? self.groupMemberItems[index] : self.inviteMembersItem;
    }
    return  nil;
}

- (NSAttributedString*) titleForSection:(DatasheetSection *)section {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return [self groupMemberSectionTitle];
    }
    return nil;
}

- (void) configureCell: (SmallContactCell*) cell withItem: (DatasheetItem*) item atIndexPath: (NSIndexPath*) indexPath {
    if ([[cell reuseIdentifier] isEqualToString: @"SmallContactCell"]) {
        Contact * contact = [self contactForItem: item];
        GroupMembership * membership = [self membershipOfContact: contact];
        cell.titleLabel.text = contact == self.group ? [UserProfile sharedProfile].nickName : contact.nickName;
        cell.titleLabel.textColor = [membership.state isEqualToString: @"invited"] ? [HXOUI theme].lightTextColor : [UIColor blackColor];
        cell.subtitleLabel.text = [membership.state isEqualToString: @"invited"] ? NSLocalizedString(membership.state, nil) : nil;
        cell.avatar.image = contact == self.group ? [UserProfile sharedProfile].avatarImage : contact.avatarImage;
        cell.avatar.defaultIcon = [[avatar_contact alloc] init];
        cell.closingSeparator = indexPath.row == self.groupMemberItems.count - 1;
    }
}

- (NSFetchedResultsController*) createFetchedResutsController {
    NSFetchedResultsController * frc = self.group ? [self createFetchedResutsControllerWithRequest: [self groupMembersFetchRequest: self.group]] : nil;
    return frc;
}

- (DatasheetItem*) groupMemberItem: (NSUInteger) index {
    Contact * contact = [self contactAtIndex: index];
    NSString * identifier = [NSString stringWithFormat: @"%@", contact.objectID];
    DatasheetItem * result = [self itemWithIdentifier: identifier cellIdentifier: [SmallContactCell reuseIdentifier]];
    result.accessoryStyle = DatasheetAccessoryDisclosure;
    return result;
}

- (NSFetchedResultsController*) createFetchedResutsControllerWithRequest: (NSFetchRequest*) fetchRequest {
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest: fetchRequest
                                                                                                managedObjectContext: self.managedObjectContext
                                                                                                  sectionNameKeyPath: nil
                                                                                                           cacheName: nil];
    if (aFetchedResultsController) {
        aFetchedResultsController.delegate = self;

        NSError *error = nil;
        if (![aFetchedResultsController performFetch:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
    return aFetchedResultsController;
}

- (NSFetchRequest*) groupMembersFetchRequest: (Group*) group {
    if ( ! group) {
        return nil;
    }
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [Contact entityName] inManagedObjectContext: self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors: @[[[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES]]];

    NSMutableArray *predicates = [NSMutableArray array];

    [predicates addObject: [NSPredicate predicateWithFormat:@"ANY groupMemberships.group == %@", self.group]];
/*
    if(searchString.length) {
        [self addSearchPredicates: predicateArray searchString: searchString];
    }
 */
    NSPredicate * filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates: predicates];
    [fetchRequest setPredicate:filterPredicate];

    [fetchRequest setFetchBatchSize:20];
    return fetchRequest;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    NSUInteger sectionIndex = [self indexPathForItem: self.groupMemberSection].section;
    switch(type) {
        case NSFetchedResultsChangeInsert:
        {
            DatasheetItem * item = [self groupMemberItem: newIndexPath.row];
            [self.groupMemberItems insertObject: item atIndex: newIndexPath.row];
            [self.delegate controller: self
                      didChangeObject: nil
                        forChangeType: DatasheetChangeInsert
                         newIndexPath: [NSIndexPath indexPathForRow: newIndexPath.row inSection: sectionIndex]];
            break;
        }
        case NSFetchedResultsChangeDelete:
            [self.groupMemberItems removeObjectAtIndex: indexPath.row];
            [self.delegate controller: self didChangeObject: [NSIndexPath indexPathForRow: indexPath.row inSection: sectionIndex] forChangeType: DatasheetChangeDelete newIndexPath: nil];
            break;

        case NSFetchedResultsChangeUpdate:
            [self.delegate controller: self didChangeObject: [NSIndexPath indexPathForRow: indexPath.row inSection: sectionIndex] forChangeType: DatasheetChangeUpdate newIndexPath: nil];
            break;
        case NSFetchedResultsChangeMove:
            break;
    }
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.delegate controllerWillChangeContent: self];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.delegate controllerDidChangeContent: self];
    //[self updateCurrentItems];
}


// Thing is: If we are displaying a group our own membership cell needs a little
// kick if we edit our own profile...
- (void) addProfileObservers {
    if ([self myMembershipItem]) {
        self.profileObserver = [[NSNotificationCenter defaultCenter] addObserverForName: @"profileUpdatedByUser"
                                                                                 object: nil
                                                                                  queue: [NSOperationQueue mainQueue]
                                                                             usingBlock: ^(NSNotification *note) {
                                                                                 [self updateItem: [self myMembershipItem]];
                                                                             }];
    }
}

- (void) removeProfileObservers {
    if (self.profileObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver: self.profileObserver];
    }
}

@synthesize inviteMembersItem = _inviteMembersItem;
- (DatasheetItem*) inviteMembersItem {
    if ( ! _inviteMembersItem) {
        _inviteMembersItem = [self itemWithIdentifier: @"group_invite_friends" cellIdentifier: @"DatasheetActionCell"];
        _inviteMembersItem.target = self;
        _inviteMembersItem.action = @selector(inviteMembersPressed:);
    }
    return _inviteMembersItem;
}

- (void) inviteMembersPressed: (id) sender {
    ContactPickerCompletion completion = ^(NSArray * result) {
        for (Contact * contact in result) {
            [self.chatBackend inviteGroupMember: contact toGroup: self.group onDone:^(BOOL success) {
                // yeah, baby
            }];
        }
    };
    id picker = [ContactPicker contactPickerWithTitle: NSLocalizedString(@"Invite:", nil)
                                                types: 0
                                                style: ContactPickerStyleMulti
                                            predicate: [NSPredicate predicateWithFormat: @"(type == %@) AND (NONE groupMemberships.group == %@)", [Contact entityName], self.group]
                                           completion: completion];

    [(UIViewController*)self.delegate presentViewController: picker animated: YES completion: nil];
}

- (NSString*) groupMemberSegueIdentifier: (NSUInteger) index {
    Contact * contact = [self contactAtIndex: index];
    return [contact isEqual: self.group] ? @"showProfile" : @"showContact";
}

- (void) editRemoveItem:(DatasheetItem *)item {
    Contact * contact = [self contactForItem: item];
    [self.chatBackend removeGroupMember: [self membershipOfContact: contact] onDeletion:^(GroupMembership *member) {
        // yeah... absolutely
    }];
}

- (GroupMembership*) membershipOfContact: (Contact*) contact {
    NSSet * matching = [self.group.members objectsPassingTest:^BOOL(id obj, BOOL *stop) {
        if ([[obj contact] isEqual: contact]) {
            *stop = YES;
            return YES;
        }
        return NO;
    }];
    if (matching.count == 0) {
        return nil;
    }
    if (matching.count != 1) {
        NSLog(@"ERROR: multiple membership for contact %@", contact);
        return nil;
    }
    return matching.anyObject;
}

#pragma mark - Attic

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = self.appDelegate.chatBackend;
    }
    return _chatBackend;
}

@synthesize appDelegate = _appDelegate;
- (AppDelegate*) appDelegate {
    if (_appDelegate == nil) {
        _appDelegate = ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    }
    return _appDelegate;
}

@synthesize managedObjectContext = _managedObjectContext;
- (NSManagedObjectContext*) managedObjectContext {
    if ( ! _managedObjectContext) {
        _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
    return _managedObjectContext;
}

@end
