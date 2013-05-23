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
#import "UIViewController+HXOSideMenuButtons.h"
#import "HXOUserDefaults.h"
#import "AssetStore.h"
#import "UserDefaultsCells.h"
#import "ProfileAvatarView.h"
#import "RadialGradientView.h"
#import "CustomNavigationBar.h"
#import "UIImage+ScaleAndCrop.h"
#import "HXOGroupedTableViewController.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "ContactListViewController.h"
#import "Contact.h"
#import "RSA.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "ChatViewController.h"
#import "ConversationViewController.h"
#import "UserProfile.h"

#import <Foundation/NSKeyValueCoding.h>

static const CGFloat kProfileEditAnimationDuration = 0.5;

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
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    
    [self configureMode];

    self.navigationItem.title = NSLocalizedString([self navigationItemTitleKey], nil);

    [self setupNavigationButtons];

    if ( ! self.isEditing) {
        _items = [self populateItems];
    }

    //if (_mode == ProfileViewModeContactProfile) {
        [self setupContactKVO];
    //}
    [HXOBackend broadcastConnectionInfo];

    [self.tableView reloadData];
}

- (void) configureMode {
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: kHXOFirstRunDone]) {
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

- (NSString*) titleForRelationshipState: (NSString*) state {
    if ([state isEqualToString: @"friend"]) {
        return [NSString stringWithFormat: NSLocalizedString(@"contact_block", nil), _contact.nickName];
    } else if ([state isEqualToString: @"blocked"]) {
        return [NSString stringWithFormat: NSLocalizedString(@"contact_unblock", nil), _contact.nickName];
    } else {
        NSLog(@"ProfileViewController titleForRelationshipState: unhandled status %@", _contact.status);
    }
    return @"Kaputt";
}

- (NSArray*) populateValues {
    id modelObject = [self getModelObject];
    _avatarItem.currentValue = [modelObject valueForKey: _avatarItem.valueKey];

    if (_mode == ProfileViewModeContactProfile) {
        _blockContactItem.currentValue = [self titleForRelationshipState: _contact.relationshipState];
    }

    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [modelObject valueForKey: item.valueKey];
    }

    [self updateKeyFingerprint];
    // XXX hack to display fingerprint while editing...
    _fingerprintInfoItem.currentValue = _fingerprintInfoItem.editLabel = NSLocalizedString(@"profile_fingerprint_info", nil);

    return [self filterItems: self.isEditing];
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
        _blockContactItem.currentValue = [self titleForRelationshipState: [object relationshipState]];
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
            UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: _fingerprintItem.indexPath];
            [cell configure: _fingerprintItem];
            [self.tableView endUpdates];
        } else {
            [item setCurrentValue: [object valueForKey: keyPath]];
            if ([keyPath isEqualToString: @"nickName"]) {
                _chatWithContactItem.currentValue = _chatWithContactItem.editLabel = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), [object nickName]];
                _blockContactItem.currentValue = [self titleForRelationshipState: [object relationshipState]];
            }
        }
        if ([item indexPath] != nil) {
            UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: [item indexPath]];
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
    UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: [_chatWithContactItem indexPath]];
    if (cell != nil) {
        [cell configure: _chatWithContactItem];
    }
}

- (void) updateBlockContactCell {
    UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: [_blockContactItem indexPath]];
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
        UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_credentials_saftey_question", nil)
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

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
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

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = NO;
    if (_contact != nil) {
        [_contact removeObserver: self forKeyPath: @"avatarImage"];
        for (ProfileItem* item in _allProfileItems) {
            [_contact removeObserver: self forKeyPath: item.valueKey];
        }
        [_contact removeObserver: self forKeyPath: @"relationshipState"];
        [_contact removeObserver: self forKeyPath: @"publicKeyId"];
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
            if (self.isEditing) {
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
            } else {
                self.navigationItem.leftBarButtonItem = self.hxoMenuButton;
            }
            ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = self.isEditing;
            break;
        case ProfileViewModeContactProfile:
            self.navigationItem.rightBarButtonItem = nil;
            break;
        default:
            NSLog(@"setupNavigationButtons: unhandled mode");

    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _items[indexPath.section][indexPath.row];
    UITableViewCell * cell = [self prototypeCellOfClass: [item cellClass]];
    if ([cell isKindOfClass: [UserDefaultsCellInfoText class]]) {
        return [(UserDefaultsCellInfoText*)cell heightForText: [item currentValue]];
    } else {
        return cell.bounds.size.height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _items[indexPath.section][indexPath.row];
    [item setIndexPath: indexPath];
    UserDefaultsCell * cell = (UserDefaultsCell*)[self dequeueReusableCellOfClass: [item cellClass] forIndexPath: indexPath];
    [cell configure: item];
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = _items[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [AvatarItem class]]) {
        return nil;
    } else {
        return item != nil && [item target] != nil && [item action] != nil ? indexPath : nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"selected cell %@", indexPath);
    id item = _items[indexPath.section][indexPath.row];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[item target] performSelector: [item action] withObject: indexPath];
#pragma clang diagnostic pop
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {

    [self.view endEditing: editing];

    [super setEditing: editing animated: animated];

    [self.tableView beginUpdates];
    NSUInteger row = 0;
    for (ProfileItem * item in _allProfileItems) {
        BOOL hasValue = [self.hasValuePredicate evaluateWithObject: item];
        NSLog(@"item=%@", item.valueKey);
        if (editing && ! hasValue) {
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForItem: row inSection: [self profileValueSectonIndex]]] withRowAnimation:UITableViewRowAnimationFade];
        } else if ( ! editing && ! hasValue) {
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForItem: row inSection: [self profileValueSectonIndex]]] withRowAnimation:UITableViewRowAnimationFade];
        }
        ++row;
    }

    [self configureEditOnlySections: editing];

    _items = [self filterItems: editing];
    [self.tableView endUpdates];
    
    for (UserDefaultsCell* cell in [self.tableView visibleCells]) {
        NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
        [cell configureBackgroundViewForPosition: indexPath.row inSectionWithCellCount: [self.tableView numberOfRowsInSection: indexPath.section]];
    }
    if (editing) {
        [self validateItems];
        //if (_mode == ProfileViewModeMyProfile) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
            ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = YES;
        //}
        _canceled = NO;
        for (ProfileItem* item in _allProfileItems) {
            [item addObserver: self forKeyPath: @"valid" options: NSKeyValueObservingOptionNew context: nil];
        }

    } else {
        if ( ! _canceled) {
            [self save];
        }
        ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
        self.navigationItem.leftBarButtonItem = [self leftNonEditButton];
        for (ProfileItem* item in _allProfileItems) {
            [item removeObserver: self forKeyPath: @"valid"];
        }
        [self onEditingDone];
    }


}

- (NSUInteger) profileValueSectonIndex {
    return 1;
}

- (UIBarButtonItem*) leftNonEditButton {
    if (_mode == ProfileViewModeMyProfile) {
        return self.hxoMenuButton;
    } else {
        return nil;
    }
}

- (void) onEditingDone {
}

- (void) configureEditOnlySections: (BOOL) editing {
    NSUInteger section = [self numberOfSectionsInTableView:self.tableView];
    if (editing) {
        [self.tableView insertSections: [NSIndexSet indexSetWithIndex: section] withRowAnimation: UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 0 inSection: section]] withRowAnimation: UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 1 inSection: section]] withRowAnimation: UITableViewRowAnimationFade];
    } else {
        section -= 1;
        [self.tableView deleteRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 0 inSection: section]] withRowAnimation: UITableViewRowAnimationFade];
        [self.tableView deleteRowsAtIndexPaths: @[[NSIndexPath indexPathForRow: 1 inSection: section]] withRowAnimation: UITableViewRowAnimationFade];
        [self.tableView deleteSections: [NSIndexSet indexSetWithIndex: section] withRowAnimation: UITableViewRowAnimationFade];
    }
}

- (IBAction)onCancel:(id)sender {
    _canceled = YES;
    [self setEditing: NO animated: YES];
}

- (NSString*) avatarDefaultImageName {
    return @"avatar_default_contact_large";
}

- (NSArray*) populateItems {
    _itemsByKeyPath = [[NSMutableDictionary alloc] init];

    _avatarItem = [[AvatarItem alloc] init];
    _avatarItem.valueKey = @"avatarImage";
    _avatarItem.cellClass = [UserDefaultsCellAvatarPicker class];
    _avatarItem.defaultImageName = [self avatarDefaultImageName];
    _avatarItem.target = self;
    _avatarItem.action = @selector(avatarTapped:);
    [_itemsByKeyPath setObject: _avatarItem forKey: _avatarItem.valueKey];

    _allProfileItems = [[NSMutableArray alloc] init];
    
    ProfileItem * nickNameItem = [[ProfileItem alloc] init];
    nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    nickNameItem.valueKey = kHXONickName;
    nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    nickNameItem.placeholder = NSLocalizedString([self namePlaceholderKey], @"Profile Placeholder Nick Name");
    nickNameItem.cellClass = [UserDefaultsCellTextInput class];
    nickNameItem.keyboardType = UIKeyboardTypeDefault;
    nickNameItem.required = YES;
    [_allProfileItems addObject: nickNameItem];
    [_itemsByKeyPath setObject: nickNameItem forKey: nickNameItem.valueKey];

#ifdef HXO_SHOW_UNIMPLEMENTED_FEATURES
    ProfileItem * phoneItem = [[ProfileItem alloc] init];
    phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
    phoneItem.valueKey = @"phoneNumber";
    phoneItem.editLabel = NSLocalizedString(@"profile_phone_label", nil);
    phoneItem.placeholder = NSLocalizedString(@"profile_phone_placeholder", nil);
    phoneItem.cellClass = [UserDefaultsCellTextInput class];
    phoneItem.keyboardType = UIKeyboardTypePhonePad;
    [_allProfileItems addObject: phoneItem];
    [_itemsByKeyPath setObject: phoneItem forKey: phoneItem.valueKey];


    ProfileItem * mailItem = [[ProfileItem alloc] init];
    mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
    mailItem.valueKey = @"mailAddress";
    mailItem.editLabel = NSLocalizedString(@"profile_mail_label",nil);
    mailItem.placeholder = NSLocalizedString(@"profile_mail_placeholder", nil);
    mailItem.cellClass = [UserDefaultsCellTextInput class];
    mailItem.keyboardType = UIKeyboardTypeEmailAddress;
    [_allProfileItems addObject: mailItem];
    [_itemsByKeyPath setObject: mailItem forKey: mailItem.valueKey];


    ProfileItem * twitterItem = [[ProfileItem alloc] init];
    twitterItem.icon = [UIImage imageNamed: @"icon_profile-twitter"];
    twitterItem.valueKey = @"twitterName";
    twitterItem.editLabel = NSLocalizedString(@"profile_twitter_label", nil);
    twitterItem.placeholder = NSLocalizedString(@"profile_twitter_placeholder", nil);
    twitterItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: twitterItem];
    [_itemsByKeyPath setObject: twitterItem forKey: twitterItem.valueKey];


    ProfileItem * facebookItem = [[ProfileItem alloc] init];
    facebookItem.icon = [UIImage imageNamed: @"icon_profile-facebook"];
    facebookItem.valueKey = @"facebookName";
    facebookItem.editLabel = NSLocalizedString(@"profile_facebook_label", nil);
    facebookItem.placeholder = NSLocalizedString(@"profile_facebook_placeholder", nil);
    facebookItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: facebookItem];
    [_itemsByKeyPath setObject: facebookItem forKey: facebookItem.valueKey];


    ProfileItem * googlePlusItem = [[ProfileItem alloc] init];
    googlePlusItem.icon = [UIImage imageNamed: @"icon_profile-googleplus"];
    googlePlusItem.valueKey = @"googlePlusName";
    googlePlusItem.editLabel = NSLocalizedString(@"profile_google_plus_label", nil);
    googlePlusItem.placeholder = NSLocalizedString(@"profile_google_plus_placeholder", nil);
    googlePlusItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: googlePlusItem];
    [_itemsByKeyPath setObject: googlePlusItem forKey: googlePlusItem.valueKey];


    ProfileItem * githubItem = [[ProfileItem alloc] init];
    githubItem.icon = [UIImage imageNamed: @"icon_profile-octocat"];
    githubItem.valueKey = @"githubName";
    githubItem.editLabel = NSLocalizedString(@"profile_github_label", nil);
    githubItem.placeholder = NSLocalizedString(@"profile_github_placeholder", nil);
    githubItem.cellClass = [UserDefaultsCellDisclosure class];
    [_allProfileItems addObject: githubItem];
    [_itemsByKeyPath setObject: githubItem forKey: githubItem.valueKey];


#endif // HXO_SHOW_UNIMPLEMENTED_FEATURES


    _chatWithContactItem = [[ProfileItem alloc] init];
    _chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), _contact.nickName];
    _chatWithContactItem.cellClass = [UserDefaultsCellDisclosure class];
    _chatWithContactItem.action = @selector(chatWithContactPressed:);
    _chatWithContactItem.target = self;
    _chatWithContactItem.alwaysShowDisclosure = YES;

    _blockContactItem = [[ProfileItem alloc] init];
    _blockContactItem.currentValue = nil;
    _blockContactItem.cellClass = [UserDefaultsCell class];
    _blockContactItem.action = @selector(toggleBlockedPressed:);
    _blockContactItem.target = self;
    //[_itemsByKeyPath setObject: _blockContactItem forKey: _blockContactItem.valueKey];

    _deleteContactItem = [[ProfileItem alloc] init];
    _deleteContactItem.currentValue = NSLocalizedString(@"delete_contact", nil);
    _deleteContactItem.cellClass = [UserDefaultsCell class];
    _deleteContactItem.action = @selector(deleteContactPressed:);
    _deleteContactItem.target = self;

    _fingerprintItem = [[ProfileItem alloc] init];
    _fingerprintItem.cellClass = [UserDefaultsCell class];
    _fingerprintItem.textAlignment = NSTextAlignmentCenter;
    // [_itemsByKeyPath setObject: _fingerprintItem forKey: _fingerprintItem.valueKey];

    _fingerprintInfoItem = [[ProfileItem alloc] init];
    _fingerprintInfoItem.cellClass = [UserDefaultsCellInfoText class];

    _renewKeyPairItem = [[ProfileItem alloc] init];
    _renewKeyPairItem.cellClass = [UserDefaultsCell class];
    _renewKeyPairItem.editLabel = NSLocalizedString(@"profile_renew_keypair", nil);
    _renewKeyPairItem.target = self;
    _renewKeyPairItem.action = @selector(renewKeypairPressed:);

    _renewKeyPairInfoItem = [[ProfileItem alloc] init];
    _renewKeyPairInfoItem.cellClass = [UserDefaultsCellInfoText class];
    _renewKeyPairInfoItem.currentValue = _renewKeyPairInfoItem.editLabel = NSLocalizedString(@"profile_renew_keypair_info", nil);

    return [self populateValues];
}

- (NSString*) namePlaceholderKey {
    return @"profile_name_placeholder";
}

- (void) validateItems {
    BOOL allValid = YES;
    for (ProfileItem* item in _allProfileItems) {
        if ( ! item.valid) {
            allValid = NO;
            break;
        }
    }
    self.editButtonItem.enabled = allValid;
}

- (NSArray*) filterItems: (BOOL) editing {
    NSArray * items;
    if (editing) {
        items = _allProfileItems;
    } else {
        items = [_allProfileItems filteredArrayUsingPredicate: self.hasValuePredicate];
    }

    return [self composeItems: items withEditFlag: editing];
}

- (NSArray*) composeItems: (NSArray*) items withEditFlag: (BOOL) editing {
    // just don't ask ... needs refactoring
    if (_mode == ProfileViewModeContactProfile) {
        return @[ @[_avatarItem], @[_chatWithContactItem, _blockContactItem], items, @[_fingerprintItem, _fingerprintInfoItem], @[_deleteContactItem]];
    } else {
        if (editing) {
            return @[ @[_avatarItem], items, @[_fingerprintItem, _fingerprintInfoItem], @[_renewKeyPairItem, _renewKeyPairInfoItem]];
        } else {
            return @[ @[_avatarItem], items, @[_fingerprintItem, _fingerprintInfoItem]];
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
    [UserProfile sharedProfile].avatarImage = scaledAvatar;
    [UserProfile sharedProfile].avatarURL = nil;
    [UserProfile sharedProfile].avatarUploadURL = nil;

    for (ProfileItem* item in _allProfileItems) {
        if (item.currentValue != nil && ! [item.currentValue isEqual: @""]) {
            [[self getModelObject] setValue: item.currentValue forKey: item.valueKey];
        }
    }

    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: kHXOFirstRunDone]) {
        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: kHXOFirstRunDone];
        [self dismissViewControllerAnimated: YES completion: nil];
    }

    [[UserProfile sharedProfile] saveProfile];
    NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void) makeLeftButtonFixedWidth {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
}

#pragma mark - Avatar Handling

- (IBAction)avatarTapped:(id)sender {
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
    id item = _items[[sender section]][[sender row]];
    id cell = [self.tableView cellForRowAtIndexPath: sender];
    if ([_contact.relationshipState isEqualToString: @"friend"]) {
        // NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: _contact.clientId handler:^(BOOL success) {
            NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if ([_contact.relationshipState isEqualToString: @"blocked"]) {
        // NSLog(@"blocked -> friend");
        [self.chatBackend unblockClient: _contact.clientId handler:^(BOOL success) {
            NSLog(@"unblockClient: %@", success ? @"success" : @"failed");
        }];
    } else {
        NSLog(@"ProfileViewController toggleBlockedPressed: unhandled status %@", _contact.status);
    }
    [self.tableView beginUpdates];
    [cell configure: item];
    [self.tableView endUpdates];

}

- (void) deleteContactPressed: (id) sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_contact_safety_question", nil)
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
    [self.chatBackend depairClient: contact.clientId handler:^(BOOL success) {
        NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        NSManagedObjectContext * moc = self.appDelegate.managedObjectContext;
        [moc deleteObject: contact];
        [self.appDelegate saveDatabase];
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

- (NSString*) attachmentPickerActionSheetTitle {
    return NSLocalizedString(@"Pick an Avatar", "Profile View Avatar Chooser Action Sheet Title");
}

- (void) prependAdditionalActionButtons:(UIActionSheet *)actionSheet {
    if (_avatarItem.currentValue != nil) {
        actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle: NSLocalizedString(@"profile_delete_avatar_button_title", nil)];
    }
}

- (void) additionalButtonPressed:(NSUInteger)buttonIndex {
    // delete avatarImage
    [self updateAvatar: nil];
}

- (void) renewKeypairPressed: (id) sender {
    [[RSA sharedInstance] cleanKeyChain];
    [self updateKeyFingerprint];
    [self.tableView beginUpdates];
    [(UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: _fingerprintItem.indexPath] configure: _fingerprintItem];
    [self.tableView endUpdates];
    [self.chatBackend updateKey];
    [self.chatBackend updatePresence];
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


