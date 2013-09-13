//
//  ProfileViewController.m
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOConfig.h"
#import "ProfileViewController.h"
#import "MFSideMenu.h"
#import "UIViewController+HXOSideMenu.h"
#import "HXOUserDefaults.h"
#import "AssetStore.h"
#import "UserDefaultsCells.h"
#import "ProfileAvatarView.h"
#import "RadialGradientView.h"
#import "HXONavigationItem.h"
#import "UIImage+ScaleAndCrop.h"
#import "HXOGroupedTableViewController.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "ContactListViewController.h"
#import "Contact.h"
#import "RSA.h"
#import "EC.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "ChatViewController.h"
#import "ConversationViewController.h"
#import "UserProfile.h"
#import "Environment.h"
#import "ProfileDataSource.h"
#import "HXOBackend.h"

#import <Foundation/NSKeyValueCoding.h>

#define RELATIONSHIP_DEBUG NO
#define ADD_DEBUG_ITEMS NO

static const CGFloat kProfileEditAnimationDuration = 0.5;
static const NSUInteger kHXOMaxNickNameLength = 25;

typedef enum ActionSheetTags {
    kActionSheetDeleteCredentials = 1,
    kActionSheetDeleteContact
} ActionSheetTag;

@interface ProfileViewController ()

@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, readonly) NSPredicate * hasValuePredicate;
@property (strong, readonly) HXOBackend * chatBackend;

@end

@implementation ProfileViewController

@synthesize attachmentPicker = _attachmentPicker;

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _mode = ProfileViewModeMyProfile;
        [HXOBackend registerConnectionInfoObserverFor:self];
        _profileDataSource = [[ProfileDataSource alloc] init];
        _profileDataSource.delegate = self;
        [self populateItems];
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    _renewKeypairRequested = NO;
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];

    [self configureMode];

    self.navigationItem.title = NSLocalizedString([self navigationItemTitleKey], nil);

    [self setupNavigationButtons];

    if ( ! self.isEditing) {
        [self populateValues];
        [_profileDataSource updateModel: [self composeModel: self.isEditing]];
    }

    [self setupContactKVO];
    [HXOBackend broadcastConnectionInfo];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    if (_mode == ProfileViewModeFirstRun) {
        if ( ! self.isEditing) {
            [self setEditing: YES animated: YES];
            if ([UserProfile sharedProfile].isRegistered) {
                NSLog(@"INFO: First run, old credentials found.");
                [self showOldCredentialsAlert];
            } else {
                [self.appDelegate setupDone: YES];
            }
        }
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    if (_contact != nil) {
        [_contact removeObserver: self forKeyPath: @"avatarImage"];
        for (ProfileItem* item in _allProfileItems) {
            [_contact removeObserver: self forKeyPath: item.valueKey];
        }
        [_contact removeObserver: self forKeyPath: @"relationshipState"];
        [_contact removeObserver: self forKeyPath: @"publicKeyId"];
    }
}

- (void) configureMode {
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        _mode = ProfileViewModeFirstRun;
    } else if (self.contact != nil) {
        _mode = ProfileViewModeContactProfile;
    } else if ([self.parentViewController isKindOfClass: [UINavigationController class]]) { // XXX find a test that works ... this is always true
        _mode = ProfileViewModeMyProfile;
    } else {
        NSLog(@"ProfileViewController viewWillAppear: Unknown mode");
    }
}

- (NSString*) navigationItemTitleKey {
    switch (_mode) {
        case ProfileViewModeMyProfile:
        case ProfileViewModeFirstRun:
            return @"navigation_title_profile";
        case ProfileViewModeContactProfile:
            return @"navigation_title_contact";
        default:
            NSLog(@"ProfileViewController navigationItemTitleKey: unhandled mode");
            return @"unhandled mode";
    }
}

- (NSString*) blockFormatForRelationshipState: (NSString*) state {
    if ([state isEqualToString: @"friend"]) {
        return NSLocalizedString(@"contact_block", nil);
    } else if ([state isEqualToString: @"blocked"]) {
        return NSLocalizedString(@"contact_unblock", nil);
    } else if ([state isEqualToString: @"kept"]) {
    } else if ([state isEqualToString: @"groupfriend"]) {
    } else if (state == nil) {
        //happens with groups
    } else {
        NSLog(@"ProfileViewController blockFormatForRelationshipState: unhandled state %@", state);
    }
    return @"";
}

- (void) populateValues {
    id modelObject = [self getModelObject];
    _avatarItem.currentValue = [modelObject valueForKey: _avatarItem.valueKey];

    _blockContactItem.valueFormat = [self blockFormatForRelationshipState: _contact.relationshipState];
    _blockContactItem.currentValue = [modelObject nickName];
    //_chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), [modelObject nickName]];
    _chatWithContactItem.currentValue = [modelObject nickName];

    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [modelObject valueForKey: item.valueKey];
    }

    [self validateItems];

    [self updateKeyFingerprint];
    // XXX hack to display fingerprint while editing...
    _fingerprintInfoItem.currentValue = _fingerprintInfoItem.editLabel = NSLocalizedString(@"profile_fingerprint_info", nil);
}

- (id) getModelObject {
    return _mode == ProfileViewModeContactProfile ? self.contact : [UserProfile sharedProfile];
}

- (void) updateKeyFingerprint {
    NSString * keyId;
    if (_mode == ProfileViewModeContactProfile) {
        keyId = _contact.publicKeyId;
    } else {
        keyId = [HXOBackend ownPublicKeyIdString];
    }

    // XXX hack to display fingerprint while editing...
    _fingerprintItem.currentValue = _fingerprintItem.editLabel = [self formatKeyIdAsFingerprint: keyId];
}

- (void) setupContactKVO {
    [self setupContactPropertyKVO: _avatarItem];
    for (ProfileItem * item in _allProfileItems) {
        [self setupContactPropertyKVO: item];
    }
    [_contact addObserver: self forKeyPath: @"relationshipState" options: NSKeyValueObservingOptionNew context: nil];
    [_contact addObserver: self forKeyPath: @"publicKeyId" options: NSKeyValueObservingOptionNew context: nil];
}

- (void) setupContactPropertyKVO: (id) item {
    [_contact addObserver: self forKeyPath: [item valueKey] options: NSKeyValueObservingOptionNew context: nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass: [ProfileItem class]] && [keyPath isEqualToString: @"valid"]) {
            [self validateItems];
    } else if ([keyPath isEqualToString: @"relationshipState"]) {
        _blockContactItem.currentValue = self.contact.nickName;
        _blockContactItem.valueFormat = [self blockFormatForRelationshipState: [object relationshipState]];
        [self.tableView beginUpdates];
        [self updateBlockContactCell];
        [self.tableView endUpdates];
    } else if ([object isKindOfClass: [Contact class]]) {
        // NSLog(@"contact keypath %@ changed", keyPath);
        id item = _itemsByKeyPath[keyPath];
        if ([keyPath isEqualToString: @"avatarImage"]) {
            [(AvatarItem*)item setCurrentValue: [object avatarImage]];
        } else if ([keyPath isEqualToString: @"publicKeyId"]) {
            [self updateKeyFingerprint];
            [self.tableView beginUpdates];
            NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _fingerprintInfoItem];
            UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
            [cell configure: _fingerprintItem];
            [self.tableView endUpdates];
        } else {
            [item setCurrentValue: [object valueForKey: keyPath]];
            if ([keyPath isEqualToString: @"nickName"]) {
                //_chatWithContactItem.currentValue = _chatWithContactItem.editLabel = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), [object nickName]];
                _chatWithContactItem.currentValue = _chatWithContactItem.editLabel = [object nickName];
                _blockContactItem.currentValue = [object nickName];
                _blockContactItem.valueFormat = [self blockFormatForRelationshipState: [object relationshipState]];
            }
        }
        NSIndexPath * indexPath = [_profileDataSource indexPathForObject: item];
        if (indexPath != nil) {
            UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
            if (cell != nil) {
                [self.tableView beginUpdates];
                [cell configure: item];
                if ([keyPath isEqualToString: @"nickName"]) {
                    [self updateChatWithContactCell];
                    [self updateBlockContactCell];
                }
                [self.tableView endUpdates];
            }
        }
    }
}

- (void) updateChatWithContactCell {
    NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _chatWithContactItem];
    UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
    if (cell != nil) {
        [cell configure: _chatWithContactItem];
    }
}

- (void) updateBlockContactCell {
    NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _blockContactItem];
    UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
    if (cell != nil) {
        [cell configure: _blockContactItem];
    }
}

- (NSString*) formatKeyIdAsFingerprint: (NSString*) keyId {
    NSMutableString * fingerprint = [[NSMutableString alloc] init];
    for (int i = 0; i < keyId.length; i += 2) {
        [fingerprint appendString: [keyId substringWithRange: NSMakeRange( i, 2)]];
        if (i + 2 < keyId.length) {
            [fingerprint appendString: @":"];
        }
    }
    return fingerprint;
}


- (void) showOldCredentialsAlert {
    NSString * title = NSLocalizedString(@"delete_credentials_alert_title", nil);
    NSString * message = NSLocalizedString(@"delete_credentials_alert_text", nil);
    NSString * keep = NSLocalizedString(@"delete_credentials_keep_title", nil);
    NSString * delete = NSLocalizedString(@"delete_credentials_delete_title", nil);
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title message: message delegate: self cancelButtonTitle: delete otherButtonTitles: keep, nil];
    [alert show];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        ActionSheet * sheet = [[ActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_credentials_saftey_question", nil)
                                                            delegate: self
                                                   cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                              destructiveButtonTitle: NSLocalizedString(@"delete_credentials_confirm", nil)
                                                   otherButtonTitles: nil];
        sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        sheet.tag = kActionSheetDeleteCredentials;
        [sheet showInView: self.view];
    } else {
        NSLog(@"Keeping old credentials");
        [self.appDelegate setupDone: NO];
    }
}

- (void)actionSheet:(ActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // NSLog(@"button index %d", buttonIndex);
    if (actionSheet.tag == kActionSheetDeleteCredentials) {
        if (buttonIndex == actionSheet.cancelButtonIndex) {
            //[self showOldCredentialsAlert];
            [self.appDelegate setupDone: NO];
        } else if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[UserProfile sharedProfile] deleteCredentials];
            [self.appDelegate setupDone: YES];
        } else {
            NSLog(@"Unhandled button index %d in delete credentials action sheet", buttonIndex);
        }
    } else if (actionSheet.tag == kActionSheetDeleteContact) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self deleteContact: self.contact];
        }
    }
}

- (void) setupNavigationButtons {
    switch (_mode) {
        case ProfileViewModeFirstRun:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.navigationItem.leftBarButtonItem = nil;
            break;
        case ProfileViewModeMyProfile:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.editButtonItem.enabled = YES;
            if (self.isEditing) {
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
            } else {
                self.navigationItem.leftBarButtonItem = [self leftNonEditButton];
            }
            break;
        case ProfileViewModeContactProfile:
            self.navigationItem.rightBarButtonItem = nil;
            break;
        default:
            NSLog(@"setupNavigationButtons: unhandled mode");

    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _profileDataSource[indexPath.section][indexPath.row];
    UITableViewCell * cell = [self prototypeCellOfClass: [item cellClass]];
    if ([cell isKindOfClass: [UserDefaultsCellInfoText class]]) {
        return [(UserDefaultsCellInfoText*)cell heightForText: [item currentValue]];
    } else {
        return cell.bounds.size.height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _profileDataSource[indexPath.section][indexPath.row];
    UserDefaultsCell * cell = (UserDefaultsCell*)[self dequeueReusableCellOfClass: [item cellClass] forIndexPath: indexPath];
    [cell configure: item];
    return cell;
}

- (void) configureCellAtIndexPath: (NSIndexPath*) indexPath {
    id item = [_profileDataSource objectAtIndexPath: indexPath];
    UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
    [cell configure: item];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 22;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _profileDataSource[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [AvatarItem class]]) {
        return nil;
    } else {
        return item != nil && [item target] != nil && [item action] != nil ? indexPath : nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"selected cell %@", indexPath);
    id item = _profileDataSource[indexPath.section][indexPath.row];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[item target] performSelector: [item action] withObject: indexPath];
#pragma clang diagnostic pop
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    
    if (_canceled) {
        [self revertItemsToSaved];
    }

    [self.view endEditing: editing];

    [super setEditing: editing animated: animated];

    [_profileDataSource updateModel: [self composeModel: editing]];
    
    for (UserDefaultsCell* cell in [self.tableView visibleCells]) {
        NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
        [cell configureBackgroundViewForPosition: indexPath.row inSectionWithCellCount: [self.tableView numberOfRowsInSection: indexPath.section]];
    }
    [self validateItems];

    ((HXONavigationItem*)self.navigationItem).flexibleLeftButton = editing;

    if (editing) {
        if (_mode != ProfileViewModeFirstRun) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
        }
        _canceled = NO;
        for (ProfileItem* item in _allProfileItems) {
            [item addObserver: self forKeyPath: @"valid" options: NSKeyValueObservingOptionNew context: nil];
        }

    } else {
        if ( ! _canceled) {
            if (_renewKeypairRequested) {
                [self performKeypairRenewal];
                _renewKeypairRequested = NO;
            }
            [self save];
        }
        self.navigationItem.leftBarButtonItem = [self leftNonEditButton];
        for (ProfileItem* item in _allProfileItems) {
            [item removeObserver: self forKeyPath: @"valid"];
        }
        [self onEditingDone];
    }
}

- (UIBarButtonItem*) leftNonEditButton {
    if (_mode == ProfileViewModeMyProfile) {
        return self.navigationController.viewControllers.count == 1 ? self.hxoMenuButton : nil;
    } else {
        return nil;
    }
}

- (void) onEditingDone {
}


- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return _profileDataSource.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_profileDataSource[section] count];
}

- (IBAction)onCancel:(id)sender {
    _canceled = YES;
    _renewKeypairRequested = NO;
    _renewKeyPairItem.editLabel = [self renewKeypairButtonTitle];

    //[self populateValues];
    [self setEditing: NO animated: YES];
}

- (NSString*) avatarDefaultImageName {
    return @"avatar_default_contact_large";
}

- (void) populateItems {
    _itemsByKeyPath = [[NSMutableDictionary alloc] init];

    _avatarItem = [[AvatarItem alloc] initWithName:@"AvatarItem"];
    _avatarItem.valueKey = @"avatarImage";
    _avatarItem.cellClass = [UserDefaultsCellAvatarPicker class];
    _avatarItem.defaultImageName = [self avatarDefaultImageName];
    _avatarItem.target = self;
    _avatarItem.action = @selector(avatarTapped:);
    [_itemsByKeyPath setObject: _avatarItem forKey: _avatarItem.valueKey];
    _avatarSection = [ProfileSection sectionWithName: @"AvatarSection" items: _avatarItem, nil];

    _allProfileItems = [[NSMutableArray alloc] init];
    
    _nickNameItem = [[ProfileItem alloc] initWithName:@"NickNameItem"];
    _nickNameItem.textAlignment = NSTextAlignmentLeft;
    _nickNameItem.icon = [UIImage imageNamed: [self nickNameIconName]];
    _nickNameItem.valueKey = kHXONickName;
    _nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    _nickNameItem.placeholder = NSLocalizedString([self namePlaceholderKey], @"Profile Placeholder Nick Name");
    _nickNameItem.cellClass = [UserDefaultsCellTextInput class];
    _nickNameItem.keyboardType = UIKeyboardTypeDefault;
    _nickNameItem.required = YES;
    _nickNameItem.maxLength = kHXOMaxNickNameLength;
    [_allProfileItems addObject: _nickNameItem];
    [_itemsByKeyPath setObject: _nickNameItem forKey: _nickNameItem.valueKey];
    
    if (ADD_DEBUG_ITEMS) {
        _clientIdItem = [[ProfileItem alloc] initWithName: @"ClientIdItem"];
        _clientIdItem.cellClass = [UserDefaultsCell class];
        _clientIdItem.textAlignment = NSTextAlignmentLeft;
        _clientIdItem.valueKey = @"clientId";
        [_allProfileItems addObject: _clientIdItem];
        [_itemsByKeyPath setObject: _clientIdItem forKey: _clientIdItem.valueKey];
        
        _groupMembershipsItem = [[ProfileItem alloc] initWithName: @"GroupMembershipsItem"];
        _groupMembershipsItem.cellClass = [UserDefaultsCell class];
        _groupMembershipsItem.textAlignment = NSTextAlignmentLeft;
        _groupMembershipsItem.valueKey = @"groupMembershipList";
        [_allProfileItems addObject: _groupMembershipsItem];
        [_itemsByKeyPath setObject: _groupMembershipsItem forKey: _groupMembershipsItem.valueKey];
    }
    
#ifdef HXO_SHOW_UNIMPLEMENTED_FEATURES
    ProfileItem * phoneItem = [[ProfileItem alloc] initWithName:@"PhoneNumberItem"];
    phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
    phoneItem.valueKey = @"phoneNumber";
    phoneItem.editLabel = NSLocalizedString(@"profile_phone_label", nil);
    phoneItem.placeholder = NSLocalizedString(@"profile_phone_placeholder", nil);
    phoneItem.cellClass = [UserDefaultsCellTextInput class];
    phoneItem.keyboardType = UIKeyboardTypePhonePad;
    [_allProfileItems addObject: phoneItem];
    [_itemsByKeyPath setObject: phoneItem forKey: phoneItem.valueKey];


    ProfileItem * mailItem = [[ProfileItem alloc] initWithName:@"MailItem"];
    mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
    mailItem.valueKey = @"mailAddress";
    mailItem.editLabel = NSLocalizedString(@"profile_mail_label",nil);
    mailItem.placeholder = NSLocalizedString(@"profile_mail_placeholder", nil);
    mailItem.cellClass = [UserDefaultsCellTextInput class];
    mailItem.keyboardType = UIKeyboardTypeEmailAddress;
    [_allProfileItems addObject: mailItem];
    [_itemsByKeyPath setObject: mailItem forKey: mailItem.valueKey];


    ProfileItem * twitterItem = [[ProfileItem alloc] initWithName:@"TwitterItem"];
    twitterItem.icon = [UIImage imageNamed: @"icon_profile-twitter"];
    twitterItem.valueKey = @"twitterName";
    twitterItem.editLabel = NSLocalizedString(@"profile_twitter_label", nil);
    twitterItem.placeholder = NSLocalizedString(@"profile_twitter_placeholder", nil);
    twitterItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: twitterItem];
    [_itemsByKeyPath setObject: twitterItem forKey: twitterItem.valueKey];


    ProfileItem * facebookItem = [[ProfileItem alloc] initWithName:@"FacebookItem"];
    facebookItem.icon = [UIImage imageNamed: @"icon_profile-facebook"];
    facebookItem.valueKey = @"facebookName";
    facebookItem.editLabel = NSLocalizedString(@"profile_facebook_label", nil);
    facebookItem.placeholder = NSLocalizedString(@"profile_facebook_placeholder", nil);
    facebookItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: facebookItem];
    [_itemsByKeyPath setObject: facebookItem forKey: facebookItem.valueKey];


    ProfileItem * googlePlusItem = [[ProfileItem alloc] initWithName:@"GooglePlusItem"];
    googlePlusItem.icon = [UIImage imageNamed: @"icon_profile-googleplus"];
    googlePlusItem.valueKey = @"googlePlusName";
    googlePlusItem.editLabel = NSLocalizedString(@"profile_google_plus_label", nil);
    googlePlusItem.placeholder = NSLocalizedString(@"profile_google_plus_placeholder", nil);
    googlePlusItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: googlePlusItem];
    [_itemsByKeyPath setObject: googlePlusItem forKey: googlePlusItem.valueKey];


    ProfileItem * githubItem = [[ProfileItem alloc] initWithName:@"GithubItem"];
    githubItem.icon = [UIImage imageNamed: @"icon_profile-octocat"];
    githubItem.valueKey = @"githubName";
    githubItem.editLabel = NSLocalizedString(@"profile_github_label", nil);
    githubItem.placeholder = NSLocalizedString(@"profile_github_placeholder", nil);
    githubItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: githubItem];
    [_itemsByKeyPath setObject: githubItem forKey: githubItem.valueKey];


#endif // HXO_SHOW_UNIMPLEMENTED_FEATURES

    _chatWithContactItem = [[ProfileItem alloc] initWithName: @"ChatWithContactItem"];
    //_chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), _contact.nickName];
    _chatWithContactItem.currentValue = _contact.nickName;
    _chatWithContactItem.valueFormat = NSLocalizedString(@"chat_with_contact", nil);
    _chatWithContactItem.textAlignment = NSTextAlignmentLeft;
    _chatWithContactItem.icon = [UIImage imageNamed: [self chatWithIconName]];
    _chatWithContactItem.cellClass = [UserDefaultsCellDisclosure class];
    _chatWithContactItem.action = @selector(chatWithContactPressed:);
    _chatWithContactItem.target = self;
    _chatWithContactItem.alwaysShowDisclosure = YES;

    _blockContactItem = [[ProfileItem alloc] initWithName: @"BlockContactItem"];
    _blockContactItem.textAlignment = NSTextAlignmentLeft;
    _blockContactItem.icon = [UIImage imageNamed: [self blockContactIconName]];
    _blockContactItem.currentValue = nil;
    _blockContactItem.cellClass = [UserDefaultsCell class];
    _blockContactItem.action = @selector(toggleBlockedPressed:);
    _blockContactItem.target = self;
    //[_itemsByKeyPath setObject: _blockContactItem forKey: _blockContactItem.valueKey];

    _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _chatWithContactItem, _blockContactItem, nil];

    _fingerprintItem = [[ProfileItem alloc] initWithName: @"FingerprintItem"];
    _fingerprintItem.cellClass = [UserDefaultsCell class];
    _fingerprintItem.textAlignment = NSTextAlignmentLeft;
    _fingerprintItem.icon = [UIImage imageNamed: [self fingerprintIconName]];
    // [_itemsByKeyPath setObject: _fingerprintItem forKey: _fingerprintItem.valueKey];
    _fingerprintInfoItem = [[ProfileItem alloc] initWithName:@"FingerprintInfoItem"];
    _fingerprintInfoItem.cellClass = [UserDefaultsCellInfoText class];

    _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem, _fingerprintInfoItem, nil];

    _renewKeyPairItem = [[ProfileItem alloc] initWithName:@"RenewKeypairItem"];
    _renewKeyPairItem.cellClass = [UserDefaultsCell class];
    _renewKeyPairItem.editLabel = [self renewKeypairButtonTitle];
    _renewKeyPairItem.target = self;
    _renewKeyPairItem.action = @selector(renewKeypairPressed:);

    _renewKeyPairInfoItem = [[ProfileItem alloc] initWithName:@"RenewKeypairInfoItem"];
    _renewKeyPairInfoItem.cellClass = [UserDefaultsCellInfoText class];
    _renewKeyPairInfoItem.currentValue = _renewKeyPairInfoItem.editLabel = NSLocalizedString(@"profile_renew_keypair_info", nil);

    _keypairSection = [ProfileSection sectionWithName: @"KeypairSection" items: _renewKeyPairItem, _renewKeyPairInfoItem, nil];

    _deleteContactItem = [[ProfileItem alloc] initWithName:@"DeleteContactItem"];
    _deleteContactItem.currentValue = NSLocalizedString(@"delete_contact", nil);
    _deleteContactItem.cellClass = [UserDefaultsCell class];
    _deleteContactItem.action = @selector(deleteContactPressed:);
    _deleteContactItem.target = self;
    _deleteContactItem.textAlignment = NSTextAlignmentLeft;
    _deleteContactItem.icon = [UIImage imageNamed: [self deleteIconName]];

    _destructiveSection = [ProfileSection sectionWithName:@"DestructiveSection" items: _deleteContactItem];

    //return [self populateValues];
}

- (NSString*) renewKeypairButtonTitle {
    if (!_renewKeypairRequested) {
        return NSLocalizedString(@"profile_renew_keypair", nil);
    } else {
        return [NSString stringWithFormat:@"%@ ✔",NSLocalizedString(@"profile_renew_keypair", nil)];
    }    
}

- (NSString*) namePlaceholderKey {
    return @"profile_name_placeholder";
}

- (NSString*) nickNameIconName {
    return @"icon_profile-name";
}

- (NSString*) fingerprintIconName {
    return @"icon_profile-fingerprint";
}

- (NSString*) blockContactIconName {
    return @"icon_profile-block.png";
}

- (NSString*) chatWithIconName {
    return @"icon_profile-chat.png";
}

- (NSString*) deleteIconName {
    return @"icon_profile-delete.png";
}


- (void) validateItems {
    BOOL allValid = YES;
    for (ProfileItem* item in _allProfileItems) {
        if ( ! item.valid) {
            //NSLog(@"profile item %@ is invalid", item.name);
            allValid = NO;
            break;
        }
    }
    if (self.isEditing) {
        self.editButtonItem.enabled = allValid;
    }
}

- (void)revertItemsToSaved {
    [self populateValues];
}

- (void) composeProfileItems: (BOOL) editing {
    if (editing) {
        _profileItemsSection = [ProfileSection sectionWithName: @"ProfileItemsSection" array: _allProfileItems];
        //items = _allProfileItems;
    } else {
        NSArray * itemsWithValue = [_allProfileItems filteredArrayUsingPredicate: self.hasValuePredicate];
        _profileItemsSection = [ProfileSection sectionWithName: @"ProfileItemsSection" array: itemsWithValue];
    }
}


- (NSArray*) composeModel: (BOOL) editing {
    // just don't ask ... needs refactoring
    [self composeProfileItems: editing];
    if (_mode == ProfileViewModeContactProfile) {
        if ([self.contact.relationshipState isEqualToString: @"friend"]) {
            _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _chatWithContactItem, _blockContactItem, nil];
            return @[ _avatarSection, _utilitySection, _profileItemsSection, _fingerprintSection, _destructiveSection];
        } else if ([self.contact.relationshipState isEqualToString: @"blocked"]) {
            _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _blockContactItem, nil];
            return @[ _avatarSection, _utilitySection, _profileItemsSection, _fingerprintSection, _destructiveSection];
        } else if ([self.contact.relationshipState isEqualToString: @"groupfriend"]) {
            return @[ _avatarSection, _profileItemsSection, _fingerprintSection, _destructiveSection];
        } else {
            return @[_avatarSection, _profileItemsSection, _fingerprintSection];
        }
    } else {
        if (editing) {
            return @[ _avatarSection, _profileItemsSection, _fingerprintSection, _keypairSection];
        } else {
            return @[ _avatarSection, _profileItemsSection, _fingerprintSection];
        }
    }
}

@synthesize hasValuePredicate = _hasValuePredicate;
- (NSPredicate*) hasValuePredicate {
    if (_hasValuePredicate == nil) {
        _hasValuePredicate = [NSPredicate predicateWithFormat: @"currentValue != NULL && currentValue != ''"];
    }
    return _hasValuePredicate;
}


- (void) save {
    // TODO: proper size handling
    CGFloat scale;
    if (_avatarItem.currentValue.size.height > _avatarItem.currentValue.size.width) {
        scale = 128.0 / _avatarItem.currentValue.size.width;
    } else {
        scale = 128.0 / _avatarItem.currentValue.size.height;
    }
    CGSize size = CGSizeMake(_avatarItem.currentValue.size.width * scale, _avatarItem.currentValue.size.height * scale);
    UIImage * scaledAvatar = [_avatarItem.currentValue imageScaledToSize: size];

    id model = [self getModelObject];
    [model setAvatarImage: scaledAvatar];
    [model setAvatarURL: nil];
    if ([model respondsToSelector: @selector(setAvatarUploadURL:)]) {
        [model setAvatarUploadURL: nil];
    }

    for (ProfileItem* item in _allProfileItems) {
        if (item.currentValue != nil && ! [item.currentValue isEqual: @""]) {
            [model setValue: item.currentValue forKey: item.valueKey];
        }
    }

    if ([model isKindOfClass: [UserProfile class]]) {
        [[UserProfile sharedProfile] saveProfile];
        NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
        [self dismissViewControllerAnimated: YES completion: nil];
    }
}

#pragma mark - Avatar Handling

- (IBAction)avatarTapped:(id)sender {
    // TODO: when we will have other text input field, make them resign first responder, too
    NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _nickNameItem];
    UserDefaultsCellTextInput * cell = (UserDefaultsCellTextInput*)[self.tableView cellForRowAtIndexPath: indexPath];
    [cell.textField resignFirstResponder];
    
    [self.attachmentPicker showInView: self.view];
}

- (void) updateAvatar: (UIImage*) image {
    _avatarItem.currentValue = image;
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: 0 inSection: 0];
    UserDefaultsCellAvatarPicker * cell = (UserDefaultsCellAvatarPicker*)[self.tableView cellForRowAtIndexPath: indexPath];
    [self.tableView beginUpdates];
    [cell configure: _avatarItem];
    [self.tableView endUpdates];
}

#pragma mark - Profile Actions

- (void) chatWithContactPressed: (id) sender {
    ConversationViewController * conversationViewController = self.appDelegate.conversationViewController;
    ChatViewController * chatViewController = conversationViewController.chatViewController;
    chatViewController.partner = self.contact;
    NSArray * viewControllers = @[conversationViewController, chatViewController];
    [self.navigationController setViewControllers: viewControllers animated: YES];
}

- (void) toggleBlockedPressed: (id) sender {
    id item = _profileDataSource[[sender section]][[sender row]];
    id cell = [self.tableView cellForRowAtIndexPath: sender];
    if ([_contact.relationshipState isEqualToString: @"friend"]) {
        // NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: _contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if ([_contact.relationshipState isEqualToString: @"blocked"]) {
        // NSLog(@"blocked -> friend");
        [self.chatBackend unblockClient: _contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"unblockClient: %@", success ? @"success" : @"failed");
        }];
    } else {
        NSLog(@"ProfileViewController toggleBlockedPressed: unhandled status %@", _contact.status);
    }
    [self.tableView beginUpdates];
    [cell configure: item];
    [self.tableView endUpdates];

}

- (void) deleteContactPressed: (id) sender {
    ActionSheet * sheet = [[ActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_contact_safety_question", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"delete_contact_confirm", nil)
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetDeleteContact;
    [sheet showInView: self.view];
}

- (void) deleteContact: (Contact*) contact {
    [self.navigationController popViewControllerAnimated: YES];
    if ([contact.relationshipState isEqualToString:@"groupfriend"]) {
        [self.chatBackend handleDeletionOfContact:contact];
        return;
    }
    [self.chatBackend depairClient: contact.clientId handler:^(BOOL success) {
        if (RELATIONSHIP_DEBUG || !success) NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        //NSManagedObjectContext * moc = self.appDelegate.managedObjectContext;
        //[moc deleteObject: contact];
        //[self.appDelegate saveDatabase];
    }];
}

#pragma mark - Attachment Picker Controller

- (AttachmentPickerController*) attachmentPicker {
    if (_attachmentPicker == nil) {
        _attachmentPicker = [[AttachmentPickerController alloc] initWithViewController: self delegate: self];
    }
    return _attachmentPicker;
}

- (BOOL) allowsEditing {
    return YES;
}

- (void) didPickAttachment:(id)attachmentInfo {
    if (attachmentInfo != nil) {
        UIImage * image = attachmentInfo[UIImagePickerControllerEditedImage];
        [self updateAvatar: image];
    }
}

- (BOOL) wantsAttachmentsOfType:(AttachmentPickerType)type {
    switch (type) {
        case AttachmentPickerTypePhotoFromCamera:
        case AttachmentPickerTypePhotoFromLibrary:
            return YES;
        default:
            return NO;
    }
}

- (BOOL) shouldSaveImagesToAlbum {
    return YES;
}

- (NSString*) attachmentPickerActionSheetTitle {
    return NSLocalizedString(@"Pick an Avatar", "Profile View Avatar Chooser Action Sheet Title");
}

- (void) prependAdditionalActionButtons:(ActionSheet *)actionSheet {
    if (_avatarItem.currentValue != nil) {
        actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle: NSLocalizedString(@"profile_delete_avatar_button_title", nil)];
    }
}

- (void) additionalButtonPressed:(NSUInteger)buttonIndex {
    // delete avatarImage
    [self updateAvatar: nil];
}

- (void)performKeypairRenewal {
    if ([HXOBackend use_elliptic_curves]) {
        [[EC sharedInstance] cleanKeyChain];
    } else {
        [[RSA sharedInstance] cleanKeyChain];
    }
    /*
    [self.chatBackend updateKeyWithHandler:^(BOOL ok) {
        [self updateKeyFingerprint];
        if (ok) {
            [self.chatBackend updatePresenceWithHandler:^(BOOL ok) {
                [self.chatBackend updateGroupKeysForMyGroupMemberships];
            }];
        }
    }];  
     */
}

- (void) renewKeypairPressed: (id) sender {
    //NSLog(@"renewKeypairPressed, sender=%@",sender);
    _renewKeypairRequested = !_renewKeypairRequested;
    
    [self updateKeyFingerprint];
    _renewKeyPairItem.editLabel = [self renewKeypairButtonTitle];
    [self.tableView beginUpdates];
    [(UserDefaultsCell*)[self.tableView cellForRowAtIndexPath:sender] configure: _renewKeyPairItem];
    [self.tableView endUpdates];
}

@synthesize chatBackend = _chatBackend;
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

@end


