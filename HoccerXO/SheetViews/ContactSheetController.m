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
#import "avatar_location.h"
#import "GroupMembership.h"
#import "SmallContactCell.h"
#import "DatasheetViewController.h"
#import "UserProfile.h"
#import "ContactPicker.h"
#import "GroupInStatuNascendi.h"
#import "KeyStatusCell.h"


//#define SHOW_CONNECTION_STATUS
//#define SHOW_UNREAD_MESSAGE_COUNT

#define DEBUG_INVITE_ITEMS NO

static const BOOL GROUPVIEW_DEBUG    = NO;
static const BOOL RELATIONSHIP_DEBUG = NO;

static int  groupMemberContext;

@interface ContactSheetController ()

@property (nonatomic, readonly) DatasheetItem              * chatItem;
@property (nonatomic, readonly) DatasheetItem              * aliasItem;
@property (nonatomic, readonly) DatasheetItem              * blockContactItem;

@property (nonatomic, readonly) DatasheetSection           * inviteContactSection;
@property (nonatomic, readonly) DatasheetItem              * inviteContactItem;

@property (nonatomic, readonly) Contact                    * contact;
@property (nonatomic, readonly) Group                      * group;
@property (nonatomic, readonly) GroupInStatuNascendi       * groupInStatuNascendi;

@property (nonatomic, readonly) DatasheetSection           * invitationResponseSection;
@property (nonatomic, readonly) DatasheetItem              * joinGroupItem;
@property (nonatomic, readonly) DatasheetItem              * invitationDeclineItem;

@property (nonatomic, readonly) DatasheetSection           * friendInvitationResponseSection;
@property (nonatomic, readonly) DatasheetItem              * acceptFriendItem;
@property (nonatomic, readonly) DatasheetItem              * refuseFriendItem;

@property (nonatomic, readonly) DatasheetSection           * groupMemberSection;
@property (nonatomic, strong)   NSMutableArray             * groupMemberItems;

@property (nonatomic, readonly) DatasheetItem              * inviteMembersItem;

@property (nonatomic, readonly) HXOBackend                 * chatBackend;
@property (nonatomic, readonly) AppDelegate                * appDelegate;

@property (nonatomic, strong)   NSFetchedResultsController * fetchedResultsController;
//@property (nonatomic, readonly) NSManagedObjectContext     * managedObjectContext;

@property (nonatomic, strong)   id                           profileObserver;

@end

@implementation ContactSheetController

@synthesize chatItem = _chatItem;
@synthesize blockContactItem = _blockContactItem;
@synthesize inviteContactSection = _inviteContactSection;
@synthesize inviteContactItem = _inviteContactItem;
@synthesize chatBackend = _chatBackend;
@synthesize groupMemberSection = _groupMemberSection;
@synthesize aliasItem = _aliasItem;

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
    self.keyItem.cellIdentifier  = @"KeyStatusCell";
    self.keyItem.title           = @"contact_key_btn_title";

    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(destructiveButtonPressed:);

    self.destructiveSection.items = @[self.blockContactItem, self.destructiveButton];
}

- (BOOL) isEditable {
    return ! self.group || ! (self.group.myGroupMembership.isInvited || self.group.isNearbyGroup);
}

- (void) registerCellClasses: (DatasheetViewController*) viewController {
    [super registerCellClasses: viewController];
    [viewController registerCellClass: [SmallContactCell class]];
    [viewController registerCellClass: [KeyStatusCell class]];
}

- (void) addUtilitySections:(NSMutableArray *)sections {
    [super addUtilitySections: sections];
    [sections addObject: self.invitationResponseSection];
    [sections addObject: self.inviteContactSection];
    [sections addObject: self.friendInvitationResponseSection];
    [sections addObject: self.groupMemberSection];
}

- (void) cancelEditing:(id)sender {
    [super cancelEditing: sender];
    if (self.groupInStatuNascendi) {
        [self.delegate controllerDidFinish: self];
    }
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

- (GroupInStatuNascendi*) groupInStatuNascendi {
    if ([self.inspectedObject isKindOfClass: [GroupInStatuNascendi class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (NSString*) title {
    return self.groupInStatuNascendi ? @"group_new_nav_title" : self.group ? @"group_nav_title" :  @"contact_nav_title";
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.aliasItem, self.chatItem, self.keyItem];
    return section;
}

- (DatasheetItem*) chatItem {
    if ( ! _chatItem) {
        _chatItem = [self itemWithIdentifier: @"contact_chat_title" cellIdentifier: @"DatasheetKeyValueCell"];
        _chatItem.dependencyPaths = @[@"messages.@count"];
        //_chatItem.visibilityMask = DatasheetModeView;
        _chatItem.accessoryStyle = DatasheetAccessoryDisclosure;
    }
    return _chatItem;
}

- (DatasheetItem*) aliasItem {
    if (! _aliasItem) {
        _aliasItem = [self itemWithIdentifier: @"contact_alias_title" cellIdentifier: @"DatasheetTextInputCell"];
        _aliasItem.valuePath = @"alias";
        _aliasItem.visibilityMask = DatasheetModeEdit;
        _aliasItem.valuePlaceholder = NSLocalizedString(@"contact_alias_placeholder", nil);
    }
    return _aliasItem;
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


- (DatasheetSection*) inviteContactSection {
    if ( ! _inviteContactSection) {
        _inviteContactSection = [DatasheetSection datasheetSectionWithIdentifier: @"invite_contact_section"];
        _inviteContactSection.items = @[self.inviteContactItem];
    }
    return _inviteContactSection;
}

- (DatasheetItem*) inviteContactItem {
    if ( ! _inviteContactItem) {
        _inviteContactItem = [self itemWithIdentifier: @"invite_contact" cellIdentifier: @"DatasheetActionCell"];
        _inviteContactItem.dependencyPaths = @[@"relationshipState", kHXONickName];
        _inviteContactItem.visibilityMask = DatasheetModeEdit;
        _inviteContactItem.target = self;
        _inviteContactItem.action = @selector(inviteToggled:);
    }
    return _inviteContactItem;
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
    if ([item isEqual: self.chatItem]) {
        return ! self.groupInStatuNascendi && [super isItemVisible: item];
        
    } else if ([item isEqual: self.aliasItem]) {
        return (self.contact.alias && ! [self.contact.alias isEqualToString: @""]) || [super isItemVisible:item];

    } else if ([item isEqual: self.blockContactItem]) {
        return (self.contact.isBlocked || self.contact.isFriend) && [super isItemVisible:item];
        
    } else if ([item isEqual: self.inviteContactItem]) {
        if (DEBUG_INVITE_ITEMS) NSLog(@"isItemVisible inviteContactItem %d %d %d %d", self.contact.isBlocked,self.contact.isFriend,self.contact.invitedMe, [super isItemVisible:item]);
        return !(self.contact.isBlocked || self.contact.isFriend || self.contact.invitedMe) && [super isItemVisible:item];
        
    } else if ([item isEqual: self.acceptFriendItem] || [item isEqual: self.refuseFriendItem]) {
        if (DEBUG_INVITE_ITEMS) NSLog(@"isItemVisible acceptFriendItem or refuseFriendItem %d %d", self.contact.invitedMe, [super isItemVisible:item]);
        return self.contact.invitedMe && [super isItemVisible: item];;
        
    } else if ([item isEqual: self.keyItem]) {
        return ! (self.group || self.groupInStatuNascendi) && [super isItemVisible: item];
        
    } else if ([item isEqual: self.inviteMembersItem]) {
        return (self.group.iAmAdmin || self.groupInStatuNascendi) && ! self.group.isNearbyGroup && [super isItemVisible: item];
        
    } else if ([item isEqual: self.joinGroupItem] || [item isEqual: self.invitationDeclineItem]) {
        return self.group.myGroupMembership.isInvited;
        
    } else if ([item isEqual: self.destructiveButton]) {
        if (self.group && self.group.isNearbyGroup && self.group.isKeptGroup) {
            return YES;
        }
        return ! self.groupInStatuNascendi && [super isItemVisible: item];
    }
    return [super isItemVisible: item];
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    if ([item isEqual: self.nicknameItem]) {
        return (self.groupInStatuNascendi || self.group.iAmAdmin) && [super isItemEnabled: item];
    } else if ([item isEqual: self.avatarItem]) {
        return self.groupInStatuNascendi || self.group.iAmAdmin;
    }

    return [super isItemEnabled: item];
}

- (BOOL) isItemDeletable:(DatasheetItem *)item {
    int index = [self.groupMemberItems indexOfObject: item];
    return (self.group.iAmAdmin || self.groupInStatuNascendi) && index != NSNotFound && ! [item isEqual: [self myMembershipItem]];
}

- (NSString*) valueFormatStringForItem:(DatasheetItem *)item {
    if ([item isEqual: self.chatItem]) {
        return self.contact.messages.count == 1 ? @"contact_message_count_format_s" : @"contact_message_count_format_p";
    }
    return nil;
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
    [super didChangeValueForItem: item];
    if ([item isEqual: self.avatarItem]) {
        self.avatarView.isBlocked = self.contact.isBlocked;
        if ( ! self.contact.avatarImage) {
            // a liitle extra somethin for those without avatars ;)
            self.avatarView.isPresent = self.contact.isPresent;
            self.avatarView.badgeText = [HXOUI messageCountBadgeText: self.contact.unreadMessages.count];
        } else {
            self.avatarView.isPresent = NO;
            self.avatarView.badgeText = nil;
        }
    } else if ([item isEqual: self.inviteMembersItem]) {
    }
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];

    if (self.groupInStatuNascendi) {
        [self.chatBackend createGroupWithHandler:^(Group * newGroup) {
            if (newGroup) {
                newGroup.nickName = self.groupInStatuNascendi.nickName;
                newGroup.alias = self.groupInStatuNascendi.alias;
                newGroup.avatarImage = self.groupInStatuNascendi.avatarImage;
                [self.chatBackend updateGroup:newGroup];
                for (int i = 1; i < self.groupInStatuNascendi.members.count; ++i) {
                    [self.chatBackend inviteGroupMember: self.groupInStatuNascendi.members[i] toGroup: newGroup onDone:^(BOOL success) {
                        // yeah, baby
                    }];
                }

                self.inspectedObject = newGroup;
            }
        }];
    } else if (self.group.iAmAdmin) {
        [self.chatBackend updateGroup: self.group];
    }
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.blockContactItem]) {
        return [self blockItemTitle];
    } else  if ([item isEqual: self.inviteContactItem]) {
        return [self inviteItemTitle];
    } else if ([item isEqual: self.destructiveButton]) {
        return [self destructiveButtonTitle];
    } else if ([item isEqual: self.inviteMembersItem]) {
        return NSLocalizedString(@"group_invite_members_title", nil);
    }
    return nil;
}

- (NSString*) valuePlaceholderForItem:(DatasheetItem *)item {
    if ([item isEqual: self.nicknameItem]) {
        return  NSLocalizedString( self.group || self.groupInStatuNascendi ? @"group_name_placeholder" : @"profile_name_placeholder", nil);
    }
    return nil;
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
        titleKey = @"key_state_unverified";
    } else if ([self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        titleKey = @"key_state_verified";
    } else {
        titleKey = @"key_state_mistrusted";
    }
    return NSLocalizedString(titleKey, nil);
}

- (NSString*) destructiveButtonTitle {
    if (self.group) {
        if (self.group.isKept) {
            return NSLocalizedString(@"group_delete_data", nil);
        }
        if (self.group.myGroupMembership.isInvited) {
            return NSLocalizedString(@"group_decline_invitation", nil);
        } else {
            if (self.group.iAmAdmin) {
                return NSLocalizedString(@"group_close", nil);
            } else {
                return NSLocalizedString(@"group_leave", nil);
            }
        }
    } else {
        return @"contact_delete_btn_title";
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
    for (int i =  self.groupMemberItems.count - 1; i >= 0; --i) {
        if ([self.groupMemberItems[i] isEqual: [self myMembershipItem]]) {
            [self.groupMemberItems removeObjectAtIndex: i];
        } else {
            [self removeGroupMemberItem: i contact: [self contactAtIndex: i]];
        }
    }
}

- (void) inspectedObjectDidChange {
    if (self.groupInStatuNascendi) {
        if (self.groupMemberItems.count == 0) {
            DatasheetItem * me = [self itemWithIdentifier: [NSString stringWithFormat: @"%p", self.groupInStatuNascendi] cellIdentifier: @"SmallContactCell"];
            me.currentValue = self.groupInStatuNascendi;
            [self.groupMemberItems addObject: me];
            [self updateCurrentItems];
        }
        if ( ! self.isEditing) {
            [self editModeChanged: nil];
        }
    }


    self.fetchedResultsController = [self createFetchedResutsController];
    if (self.fetchedResultsController) {
        for (int i = 0; i < [self.fetchedResultsController.sections[0] numberOfObjects]; ++i) {
            [self.groupMemberItems addObject: [self createGroupMemberItem: i]];
        }
    }

    [self addProfileObservers];

    self.avatarView.defaultIcon = self.group || self.groupInStatuNascendi ? [self.group.groupType isEqualToString: @"nearby"] ? [[avatar_location alloc] init] : [[avatar_group alloc] init] : [[avatar_contact alloc] init];
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
        formatKey = @"contact_block_btn_title_format";
    } else if (self.contact.isBlocked) {
        formatKey = @"contact_unblock_btn_title_format";
    }
    return formatKey ? [NSString stringWithFormat: NSLocalizedString(formatKey, nil), self.nicknameItem.currentValue] : nil;
}

- (NSString*) inviteItemTitle {
    NSString * formatKey = nil;
    if (!self.contact.isInvited) {
        formatKey = @"contact_invite_btn_title_format";
    } else if (self.contact.isInvited) {
        formatKey = @"contact_disinvite_btn_title_format";
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

- (void) inviteToggled: (id) sender {
    if (self.contact.isInvited) {
        // NSLog(@"friend -> invited");
        [self.chatBackend disinviteFriend: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"disinviteClient: %@", success ? @"success" : @"failed");
        }];
    } else if (self.contact.isGroupFriend || self.contact.isBlocked || self.contact.isKept || self.contact.isNotRelated) {
        // NSLog(@"none, blocked -> invited");
        [self.chatBackend inviteFriend: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"inviteClient: %@", success ? @"success" : @"failed");
        }];
    } else {
        NSLog(@"ContactSheetController inviteToggled: unhandled status %@", self.contact.relationshipState);
    }
}


#pragma mark - Destructive Button

- (void) destructiveButtonPressed: (UIViewController*) sender {
    NSString * title = nil;
    NSString * destructiveButtonTitle = nil;
    SEL        destructor;

    if (self.group.isKept) {
        title = NSLocalizedString(@"group_delete_title", nil);
        destructiveButtonTitle = NSLocalizedString(@"delete", nil);
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
        title = NSLocalizedString(@"contact_delete_safety_question", nil);
        destructiveButtonTitle = NSLocalizedString(@"delete", nil);
        destructor = @selector(deleteContact);
    }

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            IMP imp = [self methodForSelector: destructor];
            void (*func)(id, SEL, id) = (void *)imp;
            func(self, destructor, self);

            [self.delegate controllerDidFinish: self];
        }
    };
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(title, nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(destructiveButtonTitle, nil)
                                      otherButtonTitles: nil];
    [sheet showInView: [(id)self.delegate view]];
}

- (void) deleteGroupData {
    Group * group = self.group;
    [self quitInspection];
    [self.chatBackend deleteInDatabaseAllMembersAndContactsofGroup: group inContext:AppDelegate.instance.mainObjectContext];
    NSLog(@"ContactSheetController: cleanupGroup: deleteObject: group");
    [AppDelegate.instance deleteObject:group];
    [self.appDelegate saveDatabase];
}

- (void) deleteGroup {
    Group * group = self.group;
    [self quitInspection];
    [self.chatBackend deleteGroup: group onDeletion:^(Group *group) {
        if (group != nil) {
            if (GROUPVIEW_DEBUG) NSLog(@"Successfully deleted group %@ from server", group.nickName);
        } else {
            NSLog(@"ERROR: deleteGroup %@ failed, retrieving all groups", group);
            [self.chatBackend syncGroupsWithForce:NO withCompletion:nil];
        }
    }];
}

- (void) leaveGroup {
    Group * group = self.group;
    [self quitInspection];
    [self.chatBackend leaveGroup: group onGroupLeft:^(Group *group) {
        if (group != nil) {
            if (GROUPVIEW_DEBUG) NSLog(@"Successfully left group %@", group.nickName);
        } else {
            NSLog(@"ERROR: leaveGroup %@ failed, retrieving all groups", group);
            [self.chatBackend syncGroupsWithForce:NO withCompletion:nil];
        }
    }];
}

- (void) deleteContact {
    NSLog(@"deleting contact with relationshipState %@", self.contact.relationshipState);
    Contact * contact = self.contact;
    [self quitInspection];
    if (contact.isGroupFriend || contact.isKept) {
        //[self.chatBackend handleDeletionOfContact: contact withForce:YES];
        [self.chatBackend handleDeletionOfContact: contact withForce:YES inContext:AppDelegate.instance.mainObjectContext];
    } else {
        [self.chatBackend depairClient: contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        }];
    }
}

- (void) quitInspection {
    self.fetchedResultsController.delegate = nil;
    self.inspectedObject = nil;
    //[self.delegate controllerDidFinish:self];
}

#pragma mark - Friend Invitation Response Section

@synthesize friendInvitationResponseSection = _friendInvitationResponseSection;
- (DatasheetSection*) friendInvitationResponseSection {
    if ( ! _friendInvitationResponseSection) {
        _friendInvitationResponseSection = [DatasheetSection datasheetSectionWithIdentifier: @"friend_invitation_response_section"];
        _friendInvitationResponseSection.title = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"contact_friend_invitation_section_title",nil) attributes: nil];
        [_friendInvitationResponseSection setItems: @[self.acceptFriendItem, self.refuseFriendItem]];
    }
    return _friendInvitationResponseSection;
}

@synthesize acceptFriendItem = _acceptFriendItem;
- (DatasheetItem*) acceptFriendItem {
    if ( ! _acceptFriendItem) {
        _acceptFriendItem = [self itemWithIdentifier: @"friend_invitation_accept" cellIdentifier: @"DatasheetActionCell"];
        _acceptFriendItem.title = NSLocalizedString(@"contact_friend_accept_button", nil);
        _acceptFriendItem.target = self;
        _acceptFriendItem.action = @selector(acceptFriendTapped:);
    }
    return _acceptFriendItem;
}

@synthesize refuseFriendItem = _refuseFriendItem;
- (DatasheetItem*) refuseFriendItem {
    if ( ! _refuseFriendItem) {
        _refuseFriendItem = [self itemWithIdentifier: @"friend_invitation_refuse" cellIdentifier: @"DatasheetActionCell"];
        _refuseFriendItem.title = NSLocalizedString( @"contact_friend_refuse_button", nil);
        _refuseFriendItem.target = self;
        _refuseFriendItem.action = @selector(refuseFriendTapped:);
    }
    return _refuseFriendItem;
}

- (void) acceptFriendTapped: (id) sender {
    [self.chatBackend acceptFriend:self.contact.clientId handler:^(BOOL success) {
        NSLog(@"Accepted friend %@", self.contact.clientId);
    }];
}

- (void) refuseFriendTapped: (id) sender {
    NSString * title = NSLocalizedString(@"contact_friend_refuse_title", nil);
    NSString * destructiveButtonTitle = NSLocalizedString(@"contact_friend_refuse_button_title", nil);
    
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self.chatBackend refuseFriend:self.contact.clientId handler:^(BOOL success) {
                NSLog(@"Refused friend %@", self.contact.clientId);
            }];
        }
    };
    UIActionSheet * actionSheet = [HXOUI actionSheetWithTitle: title
                                              completionBlock: completion
                                            cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                       destructiveButtonTitle: destructiveButtonTitle
                                            otherButtonTitles: nil];
    [actionSheet showInView: [(id)self.delegate view]];
}



#pragma mark - Group Invitation Response Section

@synthesize invitationResponseSection = _invitationResponseSection;
- (DatasheetSection*) invitationResponseSection {
    if ( ! _invitationResponseSection) {
        _invitationResponseSection = [DatasheetSection datasheetSectionWithIdentifier: @"group_invitation_response_section"];
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
                                            cancelButtonTitle: NSLocalizedString(@"cancel", nil)
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
    if (self.groupInStatuNascendi) {
        return self.groupInStatuNascendi.members[index];
    }
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: index inSection: 0];
    return [[self.fetchedResultsController objectAtIndexPath: indexPath] contact];
}

- (DatasheetItem*) myMembershipItem {
    if (self.groupInStatuNascendi) {
        return self.groupMemberItems[0];
    } else if (self.group) {
        NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: self.group.myGroupMembership];
        if (indexPath.row < self.groupMemberItems.count) {
            return self.groupMemberItems[indexPath.row];
        }
    }
    return nil;
}

- (NSAttributedString*) groupMemberSectionTitle {
    NSMutableArray * admins = [[NSMutableArray alloc] init];
    if (self.group.iAmAdmin || self.groupInStatuNascendi) {
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
        NSString * label = NSLocalizedString(admins.count > 1 ? @"group_admin_label_p" : @"group_admin_label_s", nil);
        title = [label stringByAppendingString: [admins componentsJoinedByString:@", "]];
    }
    return [[NSAttributedString alloc] initWithString: title attributes: nil];
}


- (DatasheetSection*) groupMemberSection {
    if ( ! _groupMemberSection) {
        _groupMemberSection = [DatasheetSection datasheetSectionWithIdentifier: @"group_member_section"];
        _groupMemberSection.dataSource = self;
        _groupMemberSection.delegate   = self;
        _groupMemberSection.titleTextAlignment = NSTextAlignmentCenter;
    }
    return _groupMemberSection;
}

- (NSUInteger) numberOfItemsInSection:(DatasheetSection *)section {
    if ([section.identifier isEqualToString: self.groupMemberSection.identifier]) {
        return self.groupMemberItems.count + 1; // +1 is for the invite item ...
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

- (void) configureCell: (DatasheetCell*) aCell withItem: (DatasheetItem*) item atIndexPath: (NSIndexPath*) indexPath {
    if ([aCell.reuseIdentifier isEqualToString: @"SmallContactCell"]) {
        Contact * contact = [self contactForItem: item];
        GroupMembership * membership = [self membershipOfContact: contact];
        BOOL isMyMembership = [item isEqual: [self myMembershipItem]];
        BOOL isInvited = membership.isInvited;
        SmallContactCell * cell = (SmallContactCell*)aCell;
        cell.titleLabel.text      = isMyMembership ? [UserProfile sharedProfile].nickName : contact.nickName;
        cell.titleLabel.alpha     = isInvited ? 0.5 : 1;
        cell.titleLabel.textColor = [UIColor blackColor];
        cell.subtitleLabel.text   = isInvited ? NSLocalizedString(@"group_membership_state_invited", nil) : nil;
        cell.subtitleLabel.alpha  = isInvited ? 0.5 : 1;
        cell.avatar.image         = isMyMembership ? [UserProfile sharedProfile].avatarImage : contact.avatarImage;
        cell.avatar.defaultIcon   = [[avatar_contact alloc] init];
        cell.avatar.isPresent      = ! isMyMembership && contact.isPresent;
        cell.closingSeparator     = indexPath.row == self.groupMemberItems.count - 1;
    } else if ([aCell.reuseIdentifier isEqualToString: @"KeyStatusCell"]) {
        ((KeyStatusCell*)aCell).keyStatusColor = [self keyItemStatusColor];
    }
}

- (UIColor*) keyItemStatusColor {
    if (self.contact.verifiedKey == nil) {
        return [HXOUI theme].unverifiedKeyColor;
    } else if ([self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        return [HXOUI theme].verifiedKeyColor;
    } else {
        return [HXOUI theme].mistrustedKeyColor;
    }
}

- (NSFetchedResultsController*) createFetchedResutsController {
    NSFetchedResultsController * frc = self.group ? [self createFetchedResutsControllerWithRequest: [self groupMembersFetchRequest: self.group]] : nil;
    return frc;
}

- (DatasheetItem*) createGroupMemberItem: (NSUInteger) index {
    Contact * contact = [self contactAtIndex: index];
    NSString * identifier = [NSString stringWithFormat: @"%@", contact.objectID];
    DatasheetItem * item = [self itemWithIdentifier: identifier cellIdentifier: [SmallContactCell reuseIdentifier]];
    item.accessoryStyle = DatasheetAccessoryDisclosure;
    [self addContactObservers: contact];
    return item;
}

- (void) removeGroupMemberItem: (NSUInteger) index contact: (Contact*) contact {
    [self removeContactObservers: contact];
    [self.groupMemberItems removeObjectAtIndex: index];
}

- (void) addContactObservers: (Contact*) contact {
    for (id keyPath in @[@"nickName", @"avatar", @"onlineStatus"]) {
        [contact addObserver: self forKeyPath: keyPath options: NSKeyValueObservingOptionNew context: &groupMemberContext];
    }
}

- (void) removeContactObservers: (Contact*) contact {
    for (id keyPath in @[@"nickName", @"avatar", @"onlineStatus"]) {
        [contact removeObserver: self forKeyPath: keyPath context: &groupMemberContext];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &groupMemberContext) {
        [self performSelectorOnMainThread: @selector(updateCurrentItems) withObject: nil waitUntilDone: NO];
//        [self updateCurrentItems]; // Bam!
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (NSFetchedResultsController*) createFetchedResutsControllerWithRequest: (NSFetchRequest*) fetchRequest {
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest: fetchRequest
                                                                                                managedObjectContext: AppDelegate.instance.mainObjectContext
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
    NSEntityDescription *entity = [NSEntityDescription entityForName: [GroupMembership entityName] inManagedObjectContext: AppDelegate.instance.mainObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors: @[[[NSSortDescriptor alloc] initWithKey:@"contact.nickName" ascending: YES]]];

    NSMutableArray *predicates = [NSMutableArray array];

    [predicates addObject: [NSPredicate predicateWithFormat:@"group == %@", self.group]];

    NSPredicate * filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates: predicates];
    [fetchRequest setPredicate:filterPredicate];

    [fetchRequest setFetchBatchSize:20];
    return fetchRequest;
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(GroupMembership*) membership
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.groupMemberItems insertObject: [self createGroupMemberItem: newIndexPath.row] atIndex: newIndexPath.row];
            break;
        case NSFetchedResultsChangeDelete:
            [self removeGroupMemberItem: indexPath.row contact: membership.contact];
            break;

        case NSFetchedResultsChangeUpdate:
            // update is triggered in any case. see controllerDidChangeContent:
            break;
        case NSFetchedResultsChangeMove:
            NSLog(@"FIXME: unhandled change type move");
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self updateCurrentItems];
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
        if (self.groupInStatuNascendi) {
            for (Contact * contact in result) {
                DatasheetItem * contactItem = [self itemWithIdentifier: [NSString stringWithFormat: @"%@", contact.objectID] cellIdentifier: @"SmallContactCell"];
                [self addContactObservers: contact];
                [self.groupMemberItems addObject: contactItem];
                [self.groupInStatuNascendi.members addObject: contact];
            }
            [self updateCurrentItems];
        } else {
            for (Contact * contact in result) {
                [self.chatBackend inviteGroupMember: contact toGroup: self.group onDone:^(BOOL success) {
                    // yeah, baby
                }];
            }
        }
    };

    NSPredicate * predicate;
    if (self.groupInStatuNascendi) {
        predicate = [NSPredicate predicateWithFormat: @"(type == %@) AND NOT (self IN (%@))", [Contact entityName], self.groupInStatuNascendi.members];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(type == %@) AND SUBQUERY(groupMemberships, $g, $g.group == %@).@count == 0", [Contact entityName], self.group];
    }


    id picker = [ContactPicker contactPickerWithTitle: NSLocalizedString(@"Invite:", nil)
                                                types: 0
                                                style: ContactPickerStyleMulti
                                            predicate: predicate
                                           completion: completion];

    [(UIViewController*)self.delegate presentViewController: picker animated: YES completion: nil];
}

- (NSString*) groupMemberSegueIdentifier: (NSUInteger) index {
    Contact * contact = [self contactAtIndex: index];
    return [contact isEqual: self.group] || [contact isEqual: self.groupInStatuNascendi] ? @"showProfile" : @"showContact";
}

- (void) editRemoveItem:(DatasheetItem *)item {
    Contact * contact = [self contactForItem: item];
    if (self.groupInStatuNascendi) {
        NSUInteger index = [self.groupMemberItems indexOfObject: item];
        if (index == NSNotFound) {
            NSLog(@"ERROR: item not found");
        } else {
            [self removeGroupMemberItem: index contact: contact];
            [self.groupInStatuNascendi.members removeObjectAtIndex: index];
        }
        [self updateCurrentItems];
    } else {
        [self.chatBackend removeGroupMember: [self membershipOfContact: contact] onDeletion:^(GroupMembership *member) {
            // yeah... absolutely
        }];
    }
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
/*
@synthesize managedObjectContext = _managedObjectContext;
- (NSManagedObjectContext*) managedObjectContext {
    if ( ! _managedObjectContext) {
        _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
    return _managedObjectContext;
}
*/
@end
