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
#import "AvatarGroup.h"
#import "GroupMembership.h"
#import "GroupMemberCell.h"
#import "DatasheetViewController.h"
#import "UserProfile.h"


//#define SHOW_CONNECTION_STATUS
//#define SHOW_UNREAD_MESSAGE_COUNT

static const BOOL RELATIONSHIP_DEBUG = NO;

@interface ContactSheetController ()

@property (nonatomic, readonly) DatasheetItem              * chatItem;
@property (nonatomic, readonly) DatasheetItem              * blockContactItem;
@property (nonatomic, readonly) Contact                    * contact;
@property (nonatomic, readonly) Group                      * group;

@property (nonatomic, readonly) DatasheetSection           * groupMemberSection;
@property (nonatomic, strong)   NSMutableArray             * groupMemberItems;

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

    self.avatarItem.dependencyPaths = @[@"relationshipState"
#ifdef SHOW_CONNECTION_STATUS
                                        , @"connectionStatus"
#endif
#ifdef SHOW_UNREAD_MESSAGE_COUNT
                                        , @"unreadMessages.@count"
#endif
                                        ];

    //self.nicknameItem.enabledMask = DatasheetModeNone;

    self.keyItem.visibilityMask = DatasheetModeView;
    self.keyItem.dependencyPaths = @[@"verifiedKey"];

    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(deleteContactPressed:);

    //self.destructiveSection.items = [@[self.blockContactItem] arrayByAddingObjectsFromArray: self.destructiveSection.items];
    self.destructiveSection.items = @[self.blockContactItem, self.destructiveButton];
}

- (BOOL) isEditable {
    return ! self.group || ! [self.group.myGroupMembership.state isEqualToString: @"invited"];
}

- (void) registerCellClasses: (DatasheetViewController*) viewController {
    [super registerCellClasses: viewController];
    [viewController registerCellClass: [GroupMemberCell class]];
}

- (void) addUtilitySections:(NSMutableArray *)sections {
    [super addUtilitySections: sections];
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
        _chatItem.visibilityMask = DatasheetModeView;
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
    int groupMemeberIndex = [self.groupMemberItems indexOfObject: item];
    if (groupMemeberIndex != NSNotFound) {
        return @"vergnurbelt"; //[self groupMemeberStatus: groupMemeberIndex];
    } else if ([item isEqual: self.chatItem]) {
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
    }
    return [super isItemVisible: item];
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    if ([item isEqual: self.nicknameItem]) {
        return self.group.iAmAdmin && [super isItemEnabled: item];
    }
    return [super isItemEnabled: item];
}

- (BOOL) isItemDeletable:(DatasheetItem *)item {
    int index = [self.groupMemberItems indexOfObject: item];
    return index != NSNotFound; // XXX && ! [[self membershipAtIndex: index] isEqual: self.group.myGroupMembership];
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
#ifdef SHOW_CONNECTION_STATUS
        self.avatarView.isOnline = self.contact.isOnline;
#endif
#ifdef SHOW_UNREAD_MESSAGE_COUNT
        self.avatarView.badgeText = [HXOUI messageCountBadgeText: self.contact.unreadMessages.count];
#endif
    }
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.blockContactItem]) {
        return [self blockItemTitle];
    } else if ([item isEqual: self.destructiveButton]) {
        return [self destructiveButtonTitle];
    }
    return nil;
}

- (NSString*) segueIdentifierForItem:(DatasheetItem *)item {
    if ([item isEqual: self.chatItem]) {
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

    self.avatarView.defaultIcon = self.group ? [[AvatarGroup alloc] init] : [[avatar_contact alloc] init];
    self.backButtonTitle = self.contact.nickName;
    [super inspectedObjectDidChange];
}


#pragma mark - UI Actions

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([item isEqual: self.chatItem]) {
        ChatViewController * chatView = segue.destinationViewController;
        chatView.inspectedObject = self.contact;
    } else  {
        [super prepareForSegue: segue withItem: item sender: sender];
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

#pragma mark - Delete Contact

- (void) deleteContactPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock handleAnswer = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self deleteContact: self.contact];
        }
    };
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_contact_safety_question", nil)
                                                 completionBlock: handleAnswer
                                               cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"delete_contact_confirm", nil)
                                               otherButtonTitles: nil];
    [sheet showInView: sender.view];
}

- (void) deleteContact: (Contact*) contact {
    //[self.delegate controllerDidFinish: self];
    NSLog(@"deleting contact with relationshipState %@", contact.relationshipState);
    if ([contact.relationshipState isEqualToString:@"groupfriend"] || [contact.relationshipState isEqualToString:@"kept"]) {
        [self.chatBackend handleDeletionOfContact:contact];
    } else {
        [self.chatBackend depairClient: contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        }];
    }
    [self.delegate controllerDidFinish: self];
}

#pragma mark - Group Member Section

- (GroupMembership*) membershipForItem: (DatasheetItem*) groupMemberItem {
    NSInteger index = [self.groupMemberItems indexOfObject: groupMemberItem];
    if (index != NSNotFound) {
        return [self membershipAtIndex: index];
    }
    return nil;
}

- (GroupMembership*) membershipAtIndex: (NSUInteger) index {
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: index inSection: 0];
    return [self.fetchedResultsController objectAtIndexPath: indexPath];
}

- (DatasheetItem*) myMembershipItem {
    if (self.group) {
        NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: self.group.myGroupMembership];
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
        return self.groupMemberItems.count;
    }
    return 0;
}

- (DatasheetItem*) section:(DatasheetSection *)section itemAtIndex:(NSUInteger)index {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return self.groupMemberItems[index];
    }
    return  nil;
}

- (NSAttributedString*) titleForSection:(DatasheetSection *)section {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return [self groupMemberSectionTitle];
    }
    return nil;
}

- (void) configureCell: (GroupMemberCell*) cell withItem: (DatasheetItem*) item atIndexPath: (NSIndexPath*) indexPath {
    if ([[cell reuseIdentifier] isEqualToString: @"GroupMemberCell"]) {
        GroupMembership * membership = [self membershipForItem: item];
        cell.titleLabel.text = membership.contact == self.group ? [UserProfile sharedProfile].nickName : membership.contact.nickName;
        cell.titleLabel.textColor = [UIColor blackColor];
        cell.statusLabel.text = @"vergnurbelt";//[membership.state isEqualToString: @"invited"] ? NSLocalizedString(@"membership_state_invited", nil) : nil;
        cell.avatar.image = membership.contact == self.group ? [UserProfile sharedProfile].avatarImage : membership.contact.avatarImage;
        cell.avatar.defaultIcon = [[avatar_contact alloc] init];
    }
}

- (NSFetchedResultsController*) createFetchedResutsController {
    NSFetchedResultsController * frc = self.group ? [self createFetchedResutsControllerWithRequest: [self groupMembersFetchRequest: self.group]] : nil;
    return frc;
}

- (DatasheetItem*) groupMemberItem: (NSUInteger) index {
    GroupMembership * membership = [self membershipAtIndex: index];
    NSString * identifier = [NSString stringWithFormat: @"%@", membership.objectID];
    DatasheetItem * result = [self itemWithIdentifier: identifier cellIdentifier: [GroupMemberCell reuseIdentifier]];
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
    NSDictionary * vars = @{ @"group" : self.group };
    NSFetchRequest * fetchRequest =  [self.appDelegate.managedObjectModel fetchRequestFromTemplateWithName:@"GroupMembershipsByGroup" substitutionVariables: vars];
    [fetchRequest setSortDescriptors: @[[[NSSortDescriptor alloc] initWithKey:@"contact.nickName" ascending: YES]]];
    return fetchRequest;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{

    switch(type) {
        case NSFetchedResultsChangeInsert:
        {
            NSUInteger idx = newIndexPath.row;
            GroupMembership * membership = [self.fetchedResultsController objectAtIndexPath: [NSIndexPath indexPathForItem: idx inSection: 0]];
            DatasheetItem * item = [self itemWithIdentifier: [NSString stringWithFormat: @"%@", membership.objectID] cellIdentifier: [GroupMemberCell reuseIdentifier]];
            [self.groupMemberItems insertObject: item atIndex: idx];
            break;
        }
        case NSFetchedResultsChangeDelete:
            [self.groupMemberItems removeObjectAtIndex: indexPath.row];
            break;

        case NSFetchedResultsChangeUpdate:
        case NSFetchedResultsChangeMove:
            break;
    }
    [self updateCurrentItems];
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
}


// Thing is: If we are displaying a group our own membership cell needs a little
// kick if we edit our profile...
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
