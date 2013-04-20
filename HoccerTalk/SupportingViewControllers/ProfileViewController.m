//
//  ProfileViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Config.h"
#import "ProfileViewController.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "HTUserDefaults.h"
#import "iOSVersionChecks.h"
#import "AssetStore.h"
#import "UserDefaultsCells.h"
#import "ProfileAvatarView.h"
#import "RadialGradientView.h"
#import "CustomNavigationBar.h"
#import "UIImage+ScaleAndCrop.h"
#import "UserDefaultsViewController.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "ContactListViewController.h"
#import "Contact.h"
#import "RSA.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "ChatViewController.h"
#import "ConversationViewController.h"

#import <Foundation/NSKeyValueCoding.h>

static const CGFloat kProfileEditAnimationDuration = 0.5;

@interface ProfileViewController ()

@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, readonly) NSPredicate * hasValuePredicate;
@property (strong, readonly) HoccerTalkBackend * chatBackend;

@end

@implementation ProfileViewController

@synthesize attachmentPicker = _attachmentPicker;

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _mode = ProfileViewModeMyProfile;
    }
    return self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;

    if ( ! [[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        _mode = ProfileViewModeFirstRun;
        self.navigationItem.title = NSLocalizedString(@"navigation_title_profile", nil);
    } else if (self.contact != nil) {
        _mode = ProfileViewModeContactProfile;
        self.navigationItem.title = NSLocalizedString(@"navigation_title_contact", nil);
    } else if ([self.parentViewController isKindOfClass: [UINavigationController class]]) {
        _mode = ProfileViewModeMyProfile;
        self.navigationItem.title = NSLocalizedString(@"navigation_title_profile", nil);
    } else {
        NSLog(@"ProfileViewController viewWillAppear: Unknown mode");
    }
    [self setupNavigationButtons: _mode];

    _items = [self populateItems];
    [self.tableView reloadData];
}

- (NSString*) titleForRelationshipState: (NSString*) state {
    if ([state isEqualToString: @"friend"]) {
        return [NSString stringWithFormat: NSLocalizedString(@"contact_block", nil), _contact.nickName];
    } else if ([state isEqualToString: @"blocked"]) {
        return [NSString stringWithFormat: NSLocalizedString(@"contact_unblock", nil), _contact.nickName];
    } else {
        NSLog(@"ProfileViewController toggleBlockedPressed: unhandled status %@", _contact.status);
    }
    return @"Kaputt";
}

- (NSArray*) populateValues {
    id modelObject = _mode == ProfileViewModeContactProfile ? self.contact : [HTUserDefaults standardUserDefaults];
    _avatarItem.currentValue = [UIImage imageWithData: [modelObject valueForKey: _avatarItem.valueKey]];

    if (_mode == ProfileViewModeContactProfile) {
        _blockContactItem.currentValue = [self titleForRelationshipState: _contact.relationshipState];
    }

    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [modelObject valueForKey: item.valueKey];
    }

    NSString * keyId;
    if (_mode == ProfileViewModeContactProfile) {
        keyId = _contact.publicKeyId;
    } else {
        // TODO: de-duplicate code... found again in backend
        NSData * keyBits = [[RSA sharedInstance] getPublicKeyBits];
        NSData * keyHash = [[keyBits SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
        keyId = [keyHash hexadecimalString];
    }
    _fingerprintItem.currentValue = [self formatKeyIdAsFingerprint: keyId];
    _fingerprintInfoItem.currentValue = NSLocalizedString(@"profile_fingerprint_info", nil);

    if (_mode == ProfileViewModeContactProfile) {
        [self setupContactKVO];
    }
    return [self filterItems: self.isEditing];
}

- (void) setupContactKVO {
    [self setupContactPropertyKVO: _avatarItem];
    for (ProfileItem * item in _allProfileItems) {
        [self setupContactPropertyKVO: item];
    }
    [_contact addObserver: self forKeyPath: @"relationshipState" options: NSKeyValueObservingOptionNew context: nil];
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
        NSLog(@"contact keypath %@ changed", keyPath);
        id item = _itemsByKeyPath[keyPath];
        if ([keyPath isEqualToString: @"avatar"]) {
            [(AvatarItem*)item setCurrentValue: [object avatarImage]];
        } else {
            [item setCurrentValue: [object valueForKey: keyPath]];
            if ([keyPath isEqualToString: @"nickName"]) {
                _chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"chat_with_contact", nil), [object nickName]];
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
        [self setEditing: YES animated: YES];
    }
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = NO;
    for (ProfileItem* item in _allProfileItems) {
        [item removeObserver: self forKeyPath: @"valid"];
    }
    if (_contact != nil) {
        [_contact removeObserver: self forKeyPath: @"avatar"];
        for (ProfileItem* item in _allProfileItems) {
            [_contact removeObserver: self forKeyPath: item.valueKey];
        }
        [_contact removeObserver: self forKeyPath: @"relationshipState"];
    }
}

- (void) setupNavigationButtons: (ProfileViewMode) mode {
    switch (mode) {
        case ProfileViewModeFirstRun:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.navigationItem.leftBarButtonItem = nil;
            break;
        case ProfileViewModeMyProfile:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            if (self.isEditing) {
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];

            } else {
                self.navigationItem.leftBarButtonItem = self.hoccerTalkMenuButton;
            }
            ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = self.isEditing;
            break;
        case ProfileViewModeContactProfile:
            self.navigationItem.rightBarButtonItem = nil;
            break;

    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return [self prototypeCellOfClass: [UserDefaultsCellAvatarPicker class]].bounds.size.height;
    } else {
        return [self prototypeCellOfClass: [UserDefaultsCellTextInput class]].bounds.size.height;
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
    NSLog(@"selected cell %@", indexPath);
    id item = _items[indexPath.section][indexPath.row];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[item target] performSelector: [item action] withObject: indexPath];
#pragma clang diagnostic pop
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated: animated];

    [self.view endEditing: editing];

    [self.tableView beginUpdates];
    NSUInteger row = 0;
    for (ProfileItem * item in _allProfileItems) {
        BOOL hasValue = [self.hasValuePredicate evaluateWithObject: item];
        if (editing && ! hasValue) {
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForItem: row inSection: 1]] withRowAnimation:UITableViewRowAnimationFade];
        } else if ( ! editing && ! hasValue) {
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForItem: row inSection: 1]] withRowAnimation:UITableViewRowAnimationFade];
        }
        ++row;
    }
    _items = [self filterItems: editing];
    [self.tableView endUpdates];
    for (UserDefaultsCell* cell in [self.tableView visibleCells]) {
        NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
        [cell configureBackgroundViewForPosition: indexPath.row inSectionWithCellCount: [self.tableView numberOfRowsInSection: indexPath.section]];
    }
    if (editing) {
        [self validateItems];
        if (_mode == ProfileViewModeMyProfile) {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action:@selector(onCancel:)];
            ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = YES;
        }
        _canceled = NO;
    } else {
        if ( ! _canceled) {
            [self saveProfile];
        }
        ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
        self.navigationItem.leftBarButtonItem = self.hoccerTalkMenuButton;
    }
}

- (IBAction)onCancel:(id)sender {
    _canceled = YES;
    [self setEditing: NO animated: YES];
}

- (NSArray*) populateItems {
    _itemsByKeyPath = [[NSMutableDictionary alloc] init];

    _avatarItem = [[AvatarItem alloc] init];
    _avatarItem.valueKey = kHTAvatar;
    _avatarItem.contactKey = @"avatar";
    _avatarItem.cellClass = [UserDefaultsCellAvatarPicker class];
    _avatarItem.target = self;
    _avatarItem.action = @selector(avatarTapped:);
    [_itemsByKeyPath setObject: _avatarItem forKey: _avatarItem.valueKey];

    _allProfileItems = [[NSMutableArray alloc] init];
    
    ProfileItem * nickNameItem = [[ProfileItem alloc] init];
    nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    nickNameItem.valueKey = kHTNickName;
    nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    nickNameItem.placeholder = NSLocalizedString(@"profile_name_placeholder", @"Profile Placeholder Nick Name");
    nickNameItem.cellClass = [UserDefaultsCellTextInput class];
    nickNameItem.keyboardType = UIKeyboardTypeDefault;
    nickNameItem.required = YES;
    [_allProfileItems addObject: nickNameItem];
    [_itemsByKeyPath setObject: nickNameItem forKey: nickNameItem.valueKey];


#ifdef HXO_USE_USER_DEFINED_CREDENTIALS
    ProfileItem * clientIdItem = [[ProfileItem alloc] init];
    //clientIditem.icon = [UIImage imageNamed: @"icon_profile-name"];
    clientIdItem.valueKey = kHTClientId;
    clientIdItem.editLabel = @"Client Id";
    clientIdItem.placeholder = @"Your Client Id";
    clientIdItem.cellClass = [UserDefaultsCellTextInput class];
    clientIdItem.keyboardType = UIKeyboardTypeDefault;
    clientIdItem.required = YES;
    [_allProfileItems addObject: clientIdItem];
    [_itemsByKeyPath setObject: clientIdItem forKey: clientIdItem.valueKey];


#ifndef HXO_USE_USERNAME_BASED_AUTHENTICATION
    ProfileItem * passwordItem = [[ProfileItem alloc] init];
    //passwordItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    passwordItem.valueKey = kHTPassword;
    passwordItem.editLabel = @"Password";
    passwordItem.placeholder = @"Your Password";
    passwordItem.cellClass = [UserDefaultsCellTextInput class];
    passwordItem.keyboardType = UIKeyboardTypeDefault;
    passwordItem.required = YES;
    passwordItem.secure = YES;
    [_allProfileItems addObject: passwordItem];
    [_itemsByKeyPath setObject: passwordItem forKey: password.valueKey];

#endif
#endif

#ifdef HXO_SHOW_UNIMPLEMENTED_PROFILE_ENTRIES
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


#endif // HXO_SHOW_UNIMPLEMENTED_PROFILE_ENTRIES


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



    _fingerprintItem = [[ProfileItem alloc] init];
    _fingerprintItem.cellClass = [UserDefaultsCell class];
    _fingerprintItem.textAlignment = NSTextAlignmentCenter;
    //[_itemsByKeyPath setObject: _fingerprintItem forKey: _fingerprintItem.valueKey];


    _fingerprintInfoItem = [[ProfileItem alloc] init];
    _fingerprintInfoItem.cellClass = [UserDefaultsCellInfoText class];

    for (ProfileItem* item in _allProfileItems) {
        [item addObserver: self forKeyPath: @"valid" options: NSKeyValueObservingOptionNew context: nil];
    }

    return [self populateValues];
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
    // just don't ask ... needs refactoring
    if (_mode == ProfileViewModeContactProfile) {
        return @[ @[_avatarItem], @[_chatWithContactItem, _blockContactItem], items, @[_fingerprintItem, _fingerprintInfoItem]];
    } else {
        return @[ @[_avatarItem], items, @[_fingerprintItem, _fingerprintInfoItem]];
    }
}

@synthesize hasValuePredicate = _hasValuePredicate;
- (NSPredicate*) hasValuePredicate {
    if (_hasValuePredicate == nil) {
        _hasValuePredicate = [NSPredicate predicateWithFormat: @"currentValue != NULL && currentValue != ''"];
    }
    return _hasValuePredicate;
}


- (void) saveProfile {
    // TODO: proper size handling
    CGFloat scale;
    if (_avatarItem.currentValue.size.height > _avatarItem.currentValue.size.width) {
        scale = 128.0 / _avatarItem.currentValue.size.width;
    } else {
        scale = 128.0 / _avatarItem.currentValue.size.height;
    }
    CGSize size = CGSizeMake(_avatarItem.currentValue.size.width * scale, _avatarItem.currentValue.size.height * scale);
    [[HTUserDefaults standardUserDefaults] setValue: UIImagePNGRepresentation([_avatarItem.currentValue imageScaledToSize: size]) forKey: _avatarItem.valueKey];
    for (ProfileItem* item in _allProfileItems) {
        if (item.currentValue != nil && ! [item.currentValue isEqual: @""]) {
            [[HTUserDefaults standardUserDefaults] setValue: item.currentValue forKey: item.valueKey];
        }
    }

    if ( ! [[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        [[HTUserDefaults standardUserDefaults] setBool: YES forKey: kHTFirstRunDone];
#ifdef HXO_USE_USER_DEFINED_CREDENTIALS
        [(AppDelegate*)[[UIApplication sharedApplication] delegate] setupDone: YES];
#endif
        [self dismissViewControllerAnimated: YES completion: nil];
    }

    [[HTUserDefaults standardUserDefaults] synchronize];
    NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void) makeLeftButtonFixedWidth {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
}

#pragma marl - Avatar Handling

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
    ConversationViewController * conversationViewController = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).conversationViewController;
    ChatViewController * chatViewController = conversationViewController.chatViewController;
    chatViewController.partner = self.contact;
    NSArray * viewControllers = @[conversationViewController, chatViewController];
    [self.navigationController setViewControllers: viewControllers animated: YES];
}

- (void) toggleBlockedPressed: (id) sender {
    id item = _items[[sender section]][[sender row]];
    id cell = [self.tableView cellForRowAtIndexPath: sender];
    if ([_contact.relationshipState isEqualToString: @"friend"]) {
        NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: _contact.clientId handler:^(BOOL success) {
            NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if ([_contact.relationshipState isEqualToString: @"blocked"]) {
        NSLog(@"blocked -> friend");
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

@synthesize chatBackend = _chatBackend;
- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}


@end


