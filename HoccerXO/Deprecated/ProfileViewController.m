//
//  ProfileViewController.m
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewController.h"
#import "HXOUserDefaults.h"
#import "UserDefaultsCells.h"
#import "AvatarView.h"
#import "UIImage+ScaleAndCrop.h"
#import "HXOTableViewController.h"
#import "NSString+UUID.h"
#import "AppDelegate.h"
#import "ContactListViewController.h"
#import "Contact.h"
#import "CCRSA.h"
#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "ChatViewController.h"
#import "ConversationViewController.h"
#import "UserProfile.h"
#import "Environment.h"
#import "ProfileDataSource.h"
#import "HXOBackend.h"
#import "UIAlertView+BlockExtensions.h"
#import "AppDelegate.h"
#import "ImageViewController.h"
#import "UIImage+ImageEffects.h"
#import "UserDefaultsCells.h"
#import "HXOUI.h"

#import "NSData+Base64.h"

#import <Foundation/NSKeyValueCoding.h>

#define RELATIONSHIP_DEBUG NO
#define ADD_DEBUG_ITEMS NO

//static const CGFloat kProfileEditAnimationDuration = 0.5;
static const NSUInteger kHXOMaxNickNameLength = 25;

static const CGFloat kAvatarSectionHeight = 0.5 * 320 + 48;

typedef enum ActionSheetTags {
    kActionSheetDeleteCredentials = 1,
    kActionSheetDeleteContact,
    kActionSheetImportCredentials,
    kActionSheetDeleteCredentialsLate,
    kActionSheetDeleteCredentialsFile,
    kActionSheetExportPrivateKey,
    kActionSheetImportPublicKey,
    kActionSheetImportPrivateKey
} ActionSheetTag;


@interface ProfileViewController ()

@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, readonly) NSPredicate * hasValuePredicate;
@property (strong, readonly) HXOBackend * chatBackend;

@property (readonly, strong, nonatomic) ImageViewController * imageViewController;

@property (nonatomic,strong) AvatarView * avatarView;
@property (nonatomic,strong) UIImageView * avatarBackgroundView;

@property (nonatomic,strong) NSDictionary * itemsChanged; // add a NSNumber BOOL with value @ for each item (avatar, key, name) that has been edited

@end

@implementation ProfileViewController

@synthesize attachmentPicker = _attachmentPicker;
@synthesize imageViewController = _imageViewController;

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

- (void) awakeFromNib {
    CGRect frame = CGRectMake(0, 0, self.tableView.frame.size.width, kAvatarSectionHeight);
    self.avatarView = [[AvatarView alloc] initWithFrame: frame];
    [self.avatarView addTarget: self action: @selector(avatarTapped:) forControlEvents: UIControlEventTouchUpInside];
    self.tableView.tableHeaderView = self.avatarView;
    self.avatarBackgroundView = [[UIImageView alloc] initWithFrame: frame];
    //self.avatarBackgroundView.layer.borderColor = [UIColor blackColor].CGColor;
    //self.avatarBackgroundView.layer.borderWidth = 10;
    self.avatarBackgroundView.layer.masksToBounds = YES;

    self.avatarBackgroundView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.tableView addSubview: self.avatarBackgroundView];
    [self.tableView sendSubviewToBack:self.avatarBackgroundView];

    self.tableView.allowsSelection = YES;
    self.tableView.allowsSelectionDuringEditing = YES;

    [self registerCellClass: [UserDefaultsCell class]];
    [self registerCellClass: [UserDefaultsCellTextInput class]];
    [self registerCellClass: [UserDefaultsCellDisclosure class]];
    [self registerCellClass: [UserDefaultsCellInfoText class]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    CGFloat y =  scrollView.contentOffset.y + self.navigationController.navigationBar.frame.size.height + MIN(statusBarSize.width, statusBarSize.height);
    if (y  < 0) {
        CGSize restingSize = CGSizeMake(self.tableView.frame.size.width, kAvatarSectionHeight);
        self.avatarBackgroundView.frame = CGRectMake(0, y, restingSize.width - y, restingSize.height - y);
        self.avatarBackgroundView.center = CGPointMake(self.view.center.x, self.avatarBackgroundView.center.y);
    }
}

- (void) viewWillAppear:(BOOL)animated {
    _renewKeypairRequested = NO;
    [super viewWillAppear: animated];

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
    self.itemsChanged = [NSMutableDictionary new];
    if (_mode == ProfileViewModeFirstRun) {
        if ( ! self.isEditing) {
            [self setEditing: YES animated: YES];
            if ([UserProfile sharedProfile].isRegistered) {
                NSLog(@"INFO: First run, old credentials found.");
                [self showOldCredentialsAlert];
            } else {
                if ([[UserProfile sharedProfile] foundCredentialsFile]) {
                    NSLog(@"INFO: First run, no old credentials in keychain found, but credentials document found.");
                    [self showOldCredentialsDocumentAlert];
                } else {
                    [self.appDelegate setupDone: YES];
                }
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
            return @"profile_nav_title";
        case ProfileViewModeContactProfile:
            return @"contact_nav_title";
        default:
            NSLog(@"ProfileViewController navigationItemTitleKey: unhandled mode");
            return @"unhandled mode";
    }
}

- (NSString*) blockFormatForRelationshipState: (NSString*) state {
    if ([state isEqualToString: kRelationStateFriend]) {
        return NSLocalizedString(@"contact_block_btn_title_format", nil);
    } else if ([state isEqualToString: kRelationStateBlocked]) {
        return NSLocalizedString(@"contact_unblock_btn_title_format", nil);
    } else if ([state isEqualToString:kRelationStateKept]) {
    } else if ([state isEqualToString: kRelationStateGroupFriend]) {
    } else if (state == nil) {
        //happens with groups
    } else {
        NSLog(@"ProfileViewController blockFormatForRelationshipState: unhandled state %@", state);
    }
    return @"";
}

- (void) populateValues {
    id modelObject = [self getModelObject];
    UIImage * avatar = [modelObject valueForKey: _avatarItem.valueKey];
    _avatarItem.currentValue = avatar;
    if ( ! avatar) {
        avatar = [UIImage imageNamed: [self avatarDefaultImageName]];
    }
    self.avatarView.image = avatar;
    [self setAvatarBackgroundImage: avatar];


    _blockContactItem.valueFormat = [self blockFormatForRelationshipState: _contact.relationshipState];
    _blockContactItem.currentValue = [modelObject nickName];
    //_chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"contact_chat_title", nil), [modelObject nickName]];
    _chatWithContactItem.currentValue = [modelObject nickName];
    

    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [modelObject valueForKey: item.valueKey];
    }

    [self validateItems];

    [self updateKeyFingerprint];
    // XXX hack to display _fingerprintInfoItem while editing...
    _fingerprintInfoItem.currentValue = _fingerprintInfoItem.editLabel = NSLocalizedString(@"key_fingerprint_info", nil);
}

- (id) getModelObject {
    return _mode == ProfileViewModeContactProfile ? self.contact : [UserProfile sharedProfile];
}

- (void) updateKeyFingerprint {
    NSString * keyId;
    NSData * key;
    if (_mode == ProfileViewModeContactProfile) {
        keyId = _contact.publicKeyId;
        key = _contact.publicKey;
    } else {
        keyId = [[UserProfile sharedProfile] publicKeyId];
        key = [[UserProfile sharedProfile] publicKey];
    }
    if (self.contact.verifiedKey == nil || ![self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        _verifyPublicKeyItem.currentValue = NSLocalizedString((@"key_verify_public_btn_title"), nil);
    } else {
        _verifyPublicKeyItem.currentValue = NSLocalizedString((@"key_unverify_public_btn_title"), nil);
    }
    _verifyPublicKeyItem.editLabel = _verifyPublicKeyItem.currentValue;

    // XXX hack to display fingerprint while editing...
    _fingerprintItem.currentValue = [self formatKeyIdAsFingerprint: keyId forKey:key];
}

- (void) setupContactKVO {
    [self setupContactPropertyKVO: _avatarItem];
    for (ProfileItem * item in _allProfileItems) {
        [self setupContactPropertyKVO: item];
    }
    [_contact addObserver: self forKeyPath: @"relationshipState" options: NSKeyValueObservingOptionNew context: nil];
    [_contact addObserver: self forKeyPath: @"publicKeyId" options: NSKeyValueObservingOptionNew context: nil];
    [_contact addObserver: self forKeyPath: @"verifiedKey" options: NSKeyValueObservingOptionNew context: nil];
}

- (void) setupContactPropertyKVO: (id) item {
    [_contact addObserver: self forKeyPath: [item valueKey] options: NSKeyValueObservingOptionNew context: nil];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    //NSLog(@"observeValueForKeyPath: keyPath %@ ofObject %@",keyPath, object);
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
        } else if ([keyPath isEqualToString: @"publicKeyId"] || [keyPath isEqualToString: @"verifiedKey"]) {
            [self updateKeyFingerprint];
            
            [self.tableView beginUpdates];
            NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _fingerprintItem];
            UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
            [cell configure: _fingerprintItem];
            
            indexPath = [_profileDataSource indexPathForObject: _verifyPublicKeyItem];
            cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
            [cell configure: _verifyPublicKeyItem];
            
            [self.tableView endUpdates];
        } else {
            [item setCurrentValue: [object valueForKey: keyPath]];
            if ([keyPath isEqualToString: @"nickName"]) {
                //_chatWithContactItem.currentValue = _chatWithContactItem.editLabel = [NSString stringWithFormat: NSLocalizedString(@"contact_chat_title", nil), [object nickName]];
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

- (NSString*) formatKeyIdAsFingerprint: (NSString*) keyId forKey:(NSData*)theKey {
    NSMutableString * fingerprint = [[NSMutableString alloc] init];
    [fingerprint appendString:@""];
    
    if (keyId) {
        for (int i = 0; i < keyId.length-2; i += 2) {
            [fingerprint appendString: [keyId substringWithRange: NSMakeRange( i, 2)]];
            if (i + 2 < keyId.length-2) {
                [fingerprint appendString: @":"];
            }
        }
        int keySize = [CCRSA getPublicKeySize:theKey];
        [fingerprint appendString: [NSString stringWithFormat:@"-%d", keySize]];
        
        //NSLog(@"self.contact = %@", self.contact);
        if (_mode == ProfileViewModeContactProfile) {
            if (self.contact.verifiedKey == nil) {
                [fingerprint appendString: @" 🔶"];
            } else if ([self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
                [fingerprint appendString: @" ✅"];
            } else {
                [fingerprint appendString: @" 🔴"];
            }
        }
    }
    return fingerprint;
}


- (void) showOldCredentialsAlert {
    NSString * title = NSLocalizedString(@"credentials_delete_btn_title_alert_title", nil);
    NSString * message = NSLocalizedString(@"credentials_delete_btn_title_alert_text", nil);
    NSString * keep = NSLocalizedString(@"credentials_setup_keep_btn_title", nil);
    NSString * delete = NSLocalizedString(@"delete", nil);
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title message: message delegate: self cancelButtonTitle: delete otherButtonTitles: keep, nil];
    [alert show];
}
    
- (void) showOldCredentialsDocumentAlert {
    NSString * title = NSLocalizedString(@"credentials_import_safety_title", nil);
    NSString * message = NSLocalizedString(@"credentials_import_btn_title_alert_text", nil);
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: title
                                                     message: message
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 switch (buttonIndex) {
                                                     case 0:
                                                     // credentials_import_btn_title_not_button_title, perform new registration
                                                     NSLog(@"Not Importing credentials, performing registration");
                                                     [self.appDelegate setupDone: YES];
                                                     break;
                                                     case 1:
                                                     NSLog(@"Importing credentials");
                                                     [ProfileViewController importCredentials];
                                                     [self.appDelegate setupDone: NO];
                                                     break;
                                                 }
                                             }
                                           cancelButtonTitle: NSLocalizedString(@"credentials_import_btn_title_not_button_title", nil)
                                           otherButtonTitles: NSLocalizedString(@"credentials_setup_import_btn_title",nil),nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"credentials_delete_btn_title_saftey_question", nil)
                                                            delegate: self
                                                   cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                              destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                                   otherButtonTitles: nil];
        sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
        sheet.tag = kActionSheetDeleteCredentials;
        [sheet showInView: self.view];
    } else {
        NSLog(@"Keeping old credentials");
        [self.appDelegate setupDone: NO];
    }
}

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
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
    } else if (actionSheet.tag == kActionSheetDeleteCredentialsLate) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[UserProfile sharedProfile] deleteCredentials];
            [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: @"Your login credentials have been deleted. Hoccer XO will terminate now." withTitle:@"Login Credentials Deleted"];

        }
    } else if (actionSheet.tag == kActionSheetDeleteCredentialsFile) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            if ([[UserProfile sharedProfile] deleteCredentialsFile]) {
                [HXOUI showErrorAlertWithMessageAsync: @"The exported credentials have been deleted." withTitle:@"credentials_file_deleted_alert"];
            }
            // TODO: show error message if it has not been deleted
            _canceled = YES;
            [self setEditing:NO animated:NO];
        }
    } else if (actionSheet.tag == kActionSheetImportCredentials) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [ProfileViewController importCredentials];
        }
    } else if (actionSheet.tag == kActionSheetExportPrivateKey) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self doExportPrivateKey];
        }
    } else if (actionSheet.tag == kActionSheetImportPublicKey) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self doImportPublicKey];
        }
    } else if (actionSheet.tag == kActionSheetImportPrivateKey) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self doImportPrivateKey];
        }
    } else {
    }
}


+ (void)importCredentials {
    [HXOUI enterStringAlert:nil withTitle:NSLocalizedString(@"credentials_file_enter_passphrase_alert",nil) withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                     onCompletion:^(NSString *entry) {
                         if (entry != nil) {
                             int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:entry];
                             if (result == 1) {
                                 [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: @"New login credentials have been imported. Restart Hoccer XO to use them" withTitle:@"New Login Credentials Imported"];
                                 return;
                             }
                             if (result == -1) {
                                 [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_decryption_failed_message" withTitle:@"credentials_file_import_failed_title"];
                                 return;
                             }
                             if (result == 0) {
                                 [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_equals_current_message" withTitle:@"credentials_file_equals_current_title"];
                                 return;
                             }
                         }
                     }
     ];
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
                self.navigationItem.leftBarButtonItem = nil;
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
    UserDefaultsCell * cell = (UserDefaultsCell*)[self prototypeCellOfClass: [item cellClass]];
    CGFloat height;
    if ([cell isKindOfClass: [UserDefaultsCellInfoText class]]) {
        cell.label.numberOfLines = 0;
    } else {
        cell.label.numberOfLines = 1;
    }
    
    if ([item currentValue] && ! [[item currentValue] isEqualToString: @""]) {
        cell.label.text = [item currentValue];
    } else {
        cell.label.text = @"XXX";
    }
    height = [cell sizeThatFits: CGSizeMake(self.view.bounds.size.width, FLT_MAX)].height;
    return height;
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

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<ProfileItemInfo> item = _profileDataSource[indexPath.section][indexPath.row];
    if ([item isKindOfClass: [AvatarItem class]]) {
        //return nil;
        return indexPath;
    } else if ([item isKindOfClass: [ProfileItem class]]) {
        return item != nil && [item target] != nil && [item action] != nil ? indexPath : nil;
    } else {
        NSLog(@"Unhandled item type");
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"selected cell %@", indexPath);
    id<ProfileItemInfo> item = _profileDataSource[indexPath.section][indexPath.row];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [[item target] performSelector: [item action] withObject: indexPath];
#pragma clang diagnostic pop
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    
    self.avatarBackgroundView.image = editing ? [_avatarItem.currentValue applyDarkEffect] : [_avatarItem.currentValue applyLightEffect];
    
    if (_canceled) {
        [self revertItemsToSaved];
    }

    [self.view endEditing: editing];

    [super setEditing: editing animated: animated];

    [_profileDataSource updateModel: [self composeModel: editing]];
    
    [self validateItems];

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
                self.itemsChanged[@"key"] = @YES;
                _renewKeypairRequested = NO;
                _renewKeyPairItem.editLabel = _renewKeyPairItem.currentValue = [self renewKeypairButtonTitle];
                [self updateKeyFingerprint];
                [self.tableView beginUpdates];
                NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _fingerprintItem];
                UserDefaultsCell * cell = (UserDefaultsCell*)[self.tableView cellForRowAtIndexPath: indexPath];
                [cell configure: _fingerprintItem];
                [self.tableView endUpdates];
            }
            [self save];
        }
        self.navigationItem.leftBarButtonItem = nil;
        for (ProfileItem* item in _allProfileItems) {
            [item removeObserver: self forKeyPath: @"valid"];
        }
        [self onEditingDone];
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
    _renewKeyPairItem.editLabel = _renewKeyPairItem.currentValue = [self renewKeypairButtonTitle];

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
    /*
    _avatarItem.cellClass = [UserDefaultsCellAvatarPicker class];
    _avatarItem.defaultImageName = [self avatarDefaultImageName];
    _avatarItem.target = self;
    _avatarItem.action = @selector(avatarTapped:);
    [_itemsByKeyPath setObject: _avatarItem forKey: _avatarItem.valueKey];
*/
    _allProfileItems = [[NSMutableArray alloc] init];
    
    _nickNameItem = [[ProfileItem alloc] initWithName:@"NickNameItem"];
    _nickNameItem.textAlignment = NSTextAlignmentLeft;
    _nickNameItem.valueKey = kHXONickName;
    _nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    _nickNameItem.placeholder = NSLocalizedString([self namePlaceholderKey], @"Profile Placeholder Nick Name");
    _nickNameItem.cellClass = [UserDefaultsCellTextInput class];
    _nickNameItem.keyboardType = UIKeyboardTypeDefault;
    _nickNameItem.required = YES;
    _nickNameItem.maxLength = kHXOMaxNickNameLength;
    _nickNameItem.isEditable = YES;
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
    
    _chatWithContactItem = [[ProfileItem alloc] initWithName: @"ChatWithContactItem"];
    //_chatWithContactItem.currentValue = [NSString stringWithFormat: NSLocalizedString(@"contact_chat_title", nil), _contact.nickName];
    _chatWithContactItem.currentValue = _contact.nickName;
    _chatWithContactItem.valueFormat = NSLocalizedString(@"contact_chat_title", nil);
    _chatWithContactItem.textAlignment = NSTextAlignmentLeft;
    _chatWithContactItem.cellClass = [UserDefaultsCellDisclosure class];
    _chatWithContactItem.action = @selector(chatWithContactPressed:);
    _chatWithContactItem.target = self;
    _chatWithContactItem.alwaysShowDisclosure = YES;

    _blockContactItem = [[ProfileItem alloc] initWithName: @"BlockContactItem"];
    _blockContactItem.textAlignment = NSTextAlignmentLeft;
    _blockContactItem.currentValue = nil;
    _blockContactItem.cellClass = [UserDefaultsCell class];
    _blockContactItem.action = @selector(toggleBlockedPressed:);
    _blockContactItem.target = self;
    //[_itemsByKeyPath setObject: _blockContactItem forKey: _blockContactItem.valueKey];

    _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _chatWithContactItem, _blockContactItem, nil];

    _fingerprintItem = [[ProfileItem alloc] initWithName: @"FingerprintItem"];
    _fingerprintItem.cellClass = [UserDefaultsCellTextInput class];
    _fingerprintItem.textAlignment = NSTextAlignmentLeft;
    _fingerprintItem.editLabel = NSLocalizedString(@"profile_key_btn_title",nil);
    [self updateKeyFingerprint];
    //_fingerprintItem.icon = [UIImage imageNamed: [self fingerprintIconName]];
    // [_itemsByKeyPath setObject: _fingerprintItem forKey: _fingerprintItem.valueKey];
    _fingerprintInfoItem = [[ProfileItem alloc] initWithName:@"FingerprintInfoItem"];
    _fingerprintInfoItem.cellClass = [UserDefaultsCellInfoText class];

    _verifyPublicKeyItem = [[ProfileItem alloc] initWithName:@"VerifyPublicKeyItem"];
    _verifyPublicKeyItem.currentValue = NSLocalizedString(@"key_verify_public_btn_title", nil);
    _verifyPublicKeyItem.editLabel = NSLocalizedString(@"key_verify_public_btn_title", nil);
    _verifyPublicKeyItem.cellClass = [UserDefaultsCell class];
    _verifyPublicKeyItem.action = @selector(verifyPublicKeyPressed:);
    _verifyPublicKeyItem.target = self;
    _verifyPublicKeyItem.textAlignment = NSTextAlignmentLeft;
    //_verifyPublicKeyItem.icon = [UIImage imageNamed: [self _verifyPublicKeyItemIconName]];
    _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem,_verifyPublicKeyItem,_fingerprintInfoItem, nil];
    
    _renewKeyPairItem = [[ProfileItem alloc] initWithName:@"RenewKeypairItem"];
    _renewKeyPairItem.cellClass = [UserDefaultsCellDisclosure class];
    _renewKeyPairItem.editLabel = _renewKeyPairItem.currentValue = [self renewKeypairButtonTitle];
    _renewKeyPairItem.target = self;
    _renewKeyPairItem.action = @selector(renewKeypairPressed:);

    _renewKeyPairInfoItem = [[ProfileItem alloc] initWithName:@"RenewKeypairInfoItem"];
    _renewKeyPairInfoItem.cellClass = [UserDefaultsCellInfoText class];
    _renewKeyPairInfoItem.currentValue = _renewKeyPairInfoItem.editLabel = NSLocalizedString(@"key_renew_keypair_info", nil);

    _exportPublicKeyItem = [[ProfileItem alloc] initWithName:@"ExportPublicKeyItem"];
    _exportPublicKeyItem.currentValue = NSLocalizedString(@"key_export_public_btn_title", nil);
    _exportPublicKeyItem.editLabel = NSLocalizedString(@"key_export_public_btn_title", nil);
    _exportPublicKeyItem.cellClass = [UserDefaultsCell class];
    _exportPublicKeyItem.action = @selector(exportPublicKeyPressed:);
    _exportPublicKeyItem.target = self;
    _exportPublicKeyItem.textAlignment = NSTextAlignmentLeft;
    //_exportPublicKeyItem.icon = [UIImage imageNamed: [self _exportPublicKeyItemIconName]];
    
    _importPublicKeyItem = [[ProfileItem alloc] initWithName:@"ImportPublicKeyItem"];
    _importPublicKeyItem.currentValue = NSLocalizedString(@"key_import_public_btn_title", nil);
    _importPublicKeyItem.editLabel = NSLocalizedString(@"key_import_public_btn_title", nil);
    _importPublicKeyItem.cellClass = [UserDefaultsCell class];
    _importPublicKeyItem.action = @selector(importPublicKeyPressed:);
    _importPublicKeyItem.target = self;
    _importPublicKeyItem.textAlignment = NSTextAlignmentLeft;
    //_importPublicKeyItem.icon = [UIImage imageNamed: [self _importPublicKeyItemIconName]];

    _exportPrivateKeyItem = [[ProfileItem alloc] initWithName:@"ExportPrivateKeyItem"];
    _exportPrivateKeyItem.currentValue = NSLocalizedString(@"key_export_private_btn_title", nil);
    _exportPrivateKeyItem.editLabel = NSLocalizedString(@"key_export_private_btn_title", nil);
    _exportPrivateKeyItem.cellClass = [UserDefaultsCell class];
    _exportPrivateKeyItem.action = @selector(exportPrivateKeyPressed:);
    _exportPrivateKeyItem.target = self;
    _exportPrivateKeyItem.textAlignment = NSTextAlignmentLeft;
    //_exportPrivateKeyItem.icon = [UIImage imageNamed: [self _exportPrivateKeyItemIconName]];
    
    _importPrivateKeyItem = [[ProfileItem alloc] initWithName:@"ImportPrivateKeyItem"];
    _importPrivateKeyItem.currentValue = NSLocalizedString(@"key_import_private_btn_title", nil);
    _importPrivateKeyItem.editLabel = NSLocalizedString(@"key_import_private_btn_title", nil);
    _importPrivateKeyItem.cellClass = [UserDefaultsCell class];
    _importPrivateKeyItem.action = @selector(importPrivateKeyPressed:);
    _importPrivateKeyItem.target = self;
    _importPrivateKeyItem.textAlignment = NSTextAlignmentLeft;
    //_importPrivateKeyItem.icon = [UIImage imageNamed: [self _importPrivateKeyItemIconName]];
    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOManualKeyManagement]) {
        _keypairSection = [ProfileSection sectionWithName: @"KeypairSection" items: _renewKeyPairItem, _renewKeyPairInfoItem, _importPrivateKeyItem, _importPublicKeyItem, nil];
    } else {
        _keypairSection = [ProfileSection sectionWithName: @"KeypairSection" items: _renewKeyPairItem, _renewKeyPairInfoItem, nil];
    }

    _deleteContactItem = [[ProfileItem alloc] initWithName:@"DeleteContactItem"];
    _deleteContactItem.editLabel = NSLocalizedString(@"contact_delete_btn_title", nil);
    _deleteContactItem.currentValue = NSLocalizedString(@"contact_delete_btn_title", nil);
    _deleteContactItem.cellClass = [UserDefaultsCell class];
    _deleteContactItem.action = @selector(deleteContactPressed:);
    _deleteContactItem.target = self;
    _deleteContactItem.textAlignment = NSTextAlignmentLeft;

    _destructiveSection = [ProfileSection sectionWithName:@"DestructiveSection" items: _deleteContactItem];

    _exportCredentialsItem = [[ProfileItem alloc] initWithName:@"ExportCredentialsItem"];
    _exportCredentialsItem.currentValue = NSLocalizedString(@"credentials_export_btn_title", nil);
    _exportCredentialsItem.editLabel = NSLocalizedString(@"credentials_export_btn_title", nil);
    _exportCredentialsItem.cellClass = [UserDefaultsCell class];
    _exportCredentialsItem.action = @selector(exportCredentialsPressed:);
    _exportCredentialsItem.target = self;
    _exportCredentialsItem.textAlignment = NSTextAlignmentLeft;
    //_exportCredentialsItem.icon = [UIImage imageNamed: [self exportCredentialsIconName]];

    _importCredentialsItem = [[ProfileItem alloc] initWithName:@"ImportCredentialsItem"];
    _importCredentialsItem.currentValue = NSLocalizedString(@"credentials_import_btn_title", nil);
    _importCredentialsItem.editLabel = NSLocalizedString(@"credentials_import_btn_title", nil);
    _importCredentialsItem.cellClass = [UserDefaultsCell class];
    _importCredentialsItem.action = @selector(importCredentialsPressed:);
    _importCredentialsItem.target = self;
    _importCredentialsItem.textAlignment = NSTextAlignmentLeft;
    //_importCredentialsItem.icon = [UIImage imageNamed: [self exportCredentialsIconName]];

    _deleteCredentialsItem = [[ProfileItem alloc] initWithName:@"DeleteCredentialsItem"];
    _deleteCredentialsItem.currentValue = NSLocalizedString(@"credentials_delete_btn_title", nil);
    _deleteCredentialsItem.editLabel = NSLocalizedString(@"credentials_delete_btn_title", nil);
    _deleteCredentialsItem.cellClass = [UserDefaultsCell class];
    _deleteCredentialsItem.action = @selector(deleteCredentialsPressed:);
    _deleteCredentialsItem.target = self;
    _deleteCredentialsItem.textAlignment = NSTextAlignmentLeft;

    _deleteCredentialsFileItem = [[ProfileItem alloc] initWithName:@"DeleteCredentialsFileItem"];
    _deleteCredentialsFileItem.currentValue = NSLocalizedString(@"credentials_file_delete_btn_title, nil);
    _deleteCredentialsFileItem.editLabel = NSLocalizedString(@"credentials_file_delete_btn_title, nil);
    _deleteCredentialsFileItem.cellClass = [UserDefaultsCell class];
    _deleteCredentialsFileItem.action = @selector(deleteCredentialsFilePressed:);
    _deleteCredentialsFileItem.target = self;
    _deleteCredentialsFileItem.textAlignment = NSTextAlignmentLeft;
    
    _credentialsSection = [ProfileSection sectionWithName: @"CredentialsSection" items: _exportCredentialsItem, _importCredentialsItem,_deleteCredentialsFileItem, _deleteCredentialsItem, nil];
    

    _coreSection = [ProfileSection sectionWithName: @"CoreSection" items: /*_avatarItem,*/ _nickNameItem/*, _fingerprintItem, _fingerprintInfoItem*/, nil];


    //return [self populateValues];
}

- (NSString*) renewKeypairButtonTitle {
    if (!_renewKeypairRequested) {
        return NSLocalizedString(@"key_renew_keypair", nil);
    } else {
        return [NSString stringWithFormat:@"%@ ✔",NSLocalizedString(@"key_renew_keypair", nil)];
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

- (NSArray*) composeModel: (BOOL) editing {
    if (editing) {
        _profileItemsSection = [ProfileSection sectionWithName: @"ProfileItemsSection" array: _allProfileItems];
    } else {
        NSArray * itemsWithValue = [_allProfileItems filteredArrayUsingPredicate: self.hasValuePredicate];
        _profileItemsSection = [ProfileSection sectionWithName: @"ProfileItemsSection" array: itemsWithValue];
    }

    if (_mode == ProfileViewModeContactProfile) {
        if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOManualKeyManagement]) {
            _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem,_verifyPublicKeyItem,_fingerprintInfoItem,_exportPublicKeyItem,_importPublicKeyItem, nil];
        } else {
            _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem,_verifyPublicKeyItem,_fingerprintInfoItem,nil];
        }

        if ([self.contact.relationshipState isEqualToString: kRelationStateFriend]) {
            _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _chatWithContactItem, _blockContactItem, nil];
            return @[ _coreSection, _utilitySection/*, _profileItemsSection*/, _fingerprintSection, _destructiveSection];
        } else if ([self.contact.relationshipState isEqualToString: kRelationStateBlocked]) {
            _utilitySection = [ProfileSection sectionWithName: @"UtilitySection" items: _blockContactItem, nil];
            return @[ _coreSection, _utilitySection/*, _profileItemsSection*/, _fingerprintSection, _destructiveSection];
        } else if ([self.contact.relationshipState isEqualToString: kRelationStateGroupFriend]) {
            return @[ _coreSection/*, _profileItemsSection*/, _fingerprintSection, _destructiveSection];
        } else if ([self.contact.relationshipState isEqualToString: kRelationStateKept]) {
            return @[ _coreSection/*, _profileItemsSection*/, _fingerprintSection, _destructiveSection];
        } else {
            return @[_coreSection, _fingerprintSection];//, _profileItemsSection, _fingerprintSection];
        }
    } else {
        if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOManualKeyManagement]) {
            _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem,_fingerprintInfoItem, _exportPublicKeyItem,_exportPrivateKeyItem,nil];
            _keypairSection = [ProfileSection sectionWithName: @"KeypairSection" items: _renewKeyPairItem, _renewKeyPairInfoItem, _importPrivateKeyItem, _importPublicKeyItem, nil];
        } else {
            _fingerprintSection = [ProfileSection sectionWithName: @"FingerprintSection" items: _fingerprintItem,_fingerprintInfoItem,nil];
            _keypairSection = [ProfileSection sectionWithName: @"KeypairSection" items: _renewKeyPairItem, _renewKeyPairInfoItem, nil];
        }
        if (editing) {
            if (_mode == ProfileViewModeFirstRun) {
                return @[ _coreSection/*, _profileItemsSection*/, _fingerprintSection, _keypairSection];
            } else {
                if ([[UserProfile sharedProfile] foundCredentialsFile]) {
                    _credentialsSection = [ProfileSection sectionWithName: @"CredentialsSection" items: _exportCredentialsItem, _importCredentialsItem, _deleteCredentialsFileItem, _deleteCredentialsItem, nil];
                } else {
                    _credentialsSection = [ProfileSection sectionWithName: @"CredentialsSection" items: _exportCredentialsItem, _deleteCredentialsItem, nil];
                }
                return @[ _coreSection/*, _profileItemsSection*/, _fingerprintSection, _keypairSection, _credentialsSection];
            }
        } else {
            return @[ _coreSection, _fingerprintSection];//, _profileItemsSection, _fingerprintSection];
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
    NSMutableDictionary changeSet = [NSMutableDictionary new];
    
    CGFloat scale;
    if (_avatarItem.currentValue.size.height > _avatarItem.currentValue.size.width) {
        scale = 128.0 / _avatarItem.currentValue.size.width;
    } else {
        scale = 128.0 / _avatarItem.currentValue.size.height;
    }
    CGSize size = CGSizeMake(_avatarItem.currentValue.size.width * scale, _avatarItem.currentValue.size.height * scale);
    UIImage * scaledAvatar = [_avatarItem.currentValue imageScaledToSize: size];

    id model = [self getModelObject];
    
    NSNumber * avatarChanged = self.itemsChanged[@"avatar"];
    if ([avatarChanged boolValue]) {
        [model setAvatarImage: scaledAvatar];
        [model setAvatarURL: nil];
        if ([model respondsToSelector: @selector(setAvatarUploadURL:)]) {
            [model setAvatarUploadURL: nil];
        }
    }

    for (ProfileItem* item in _allProfileItems) {
        
        if (item.currentValue != nil && ! [item.currentValue isEqual: @""]) {
            if (![item.currentValue isEqual:model valueForKey:item.valueKey]) {
                self.itemsChanged[item.name] = @YES;
            }
            [model setValue: item.currentValue forKey: item.valueKey];
        }
    }
    
    if ([model isKindOfClass: [UserProfile class]]) {
        [[UserProfile sharedProfile] saveProfile];
        id userInfo = @{ @"itemsChanged":self.itemsChanged};
        NSLog(@"profileUpdatedByUser info %@",userInfo);
        NSNotification *notification = [NSNotification notificationWithName:@"profileUpdatedByUser" object:self userInfo:userInfo];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]]) {
        [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
        [self dismissViewControllerAnimated: YES completion: nil];
    }
}

#pragma mark - Avatar Handling

- (ImageViewController*) imageViewController {
    if (_imageViewController == nil) {
        _imageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    }
    return _imageViewController;
}


- (void) viewAvatar:(UIImage *)avatarImage {
    //NSLog(@"viewAvatar");
    if (avatarImage != nil) {
        self.imageViewController.image = avatarImage;
        //[self presentViewController: self.imageViewController animated: YES completion: nil];
        [self.navigationController pushViewController: self.imageViewController animated: YES];
    }
}

- (IBAction)avatarTapped:(id)sender {
    // TODO: when we will have other text input field, make them resign first responder, too
    NSIndexPath * indexPath = [_profileDataSource indexPathForObject: _nickNameItem];
    UserDefaultsCellTextInput * cell = (UserDefaultsCellTextInput*)[self.tableView cellForRowAtIndexPath: indexPath];
    [cell.textField resignFirstResponder];
    if (self.editing) {
        [self.attachmentPicker showInView: self.view];
    } else {
        id modelObject = [self getModelObject];
        [self viewAvatar:[modelObject valueForKey: _avatarItem.valueKey]];
    }
}

- (void) updateAvatar: (UIImage*) image {
    _avatarItem.currentValue = image;
    if ( ! image) {
        image = [UIImage imageNamed: [self avatarDefaultImageName]];
    }
    self.avatarView.image = image;
    [self setAvatarBackgroundImage: image];
}

- (void) setAvatarBackgroundImage: (UIImage*) newImage {
    newImage = self.isEditing ? [newImage applyDarkEffect] : [newImage applyLightEffect];
    self.avatarBackgroundView.image = newImage;
}

#pragma mark - Profile Actions

- (void) chatWithContactPressed: (id) sender {
    [self.appDelegate jumpToChat: self.contact];
}

- (void) toggleBlockedPressed: (id) sender {
    id item = _profileDataSource[[sender section]][[sender row]];
    id cell = [self.tableView cellForRowAtIndexPath: sender];
    if ([_contact.relationshipState isEqualToString: kRelationStateFriend]) {
        // NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: _contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if ([_contact.relationshipState isEqualToString: kRelationStateBlocked]) {
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
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"contact_delete_safety_question", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"contact_delete_confirm", nil)
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetDeleteContact;
    [sheet showInView: self.view];
}

- (void) deleteContact: (Contact*) contact {
    [self.navigationController popViewControllerAnimated: YES];
    NSLog(@"deleting contact with relationshipState %@", contact.relationshipState);
    if ([contact.relationshipState isEqualToString: kRelationStateGroupFriend] || [contact.relationshipState isEqualToString: kRelationStateKept]) {
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

+ (void) exportCredentials {
    [HXOUI enterStringAlert:nil withTitle:NSLocalizedString(@"credentials_file_enter_passphrase_alert",nil) withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                     onCompletion:^(NSString *entry) {
                         if (entry != nil) {
                             [[UserProfile sharedProfile] exportCredentialsWithPassphrase:entry];
                             [HXOUI showErrorAlertWithMessageAsync: nil withTitle:@"credentials_exported_alert"];
                         }
                     }];
}

- (void) exportCredentialsPressed: (id) sender {
    [ProfileViewController exportCredentials];
    _canceled = YES;
    [self setEditing:NO animated:NO];
}


- (void) importPublicKeyPressed: (id) sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"key_import_safety_question", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"key_import_confirm_btn_title", nil)
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetImportPublicKey;
    [sheet showInView: self.view];
}

- (void) importPrivateKeyPressed: (id) sender {
     UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"key_import_safety_question", nil)
     delegate: self
     cancelButtonTitle: NSLocalizedString(@"cancel", nil)
     destructiveButtonTitle: NSLocalizedString(@"key_import_confirm_btn_title", nil)
     otherButtonTitles: nil];
     sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
     sheet.tag = kActionSheetImportPrivateKey;
     [sheet showInView: self.view];
}

- (void) exportPublicKeyPressed: (id) sender {
    NSData * myKeyBits;
    NSURL * myUrl;
    if (_mode == ProfileViewModeContactProfile) {
        myKeyBits = self.contact.publicKey;
        myUrl = [UserProfile getKeyFileURLWithKeyTypeName:@"pubkey" forUser:self.contact.nickName withKeyId:self.contact.publicKeyId];
    } else if (_mode == ProfileViewModeMyProfile) {
        myKeyBits = [[CCRSA sharedInstance] getPublicKeyBits];
        myUrl = [UserProfile getKeyFileURLWithKeyTypeName:@"ownpubkey" forUser:[[self getModelObject] nickName] withKeyId:self.contact.publicKeyId];
    }
    if (myKeyBits != nil) {
        NSString * exportStuff = [CCRSA makeX509FormattedPublicKey:myKeyBits];
        NSError * myError = nil;
        [[UIPasteboard generalPasteboard] setString:exportStuff];
        //[exportStuff writeToURL:myUrl atomically:NO encoding:NSUTF8StringEncoding error:&myError];
        if (myError== nil) {
            [HXOUI showErrorAlertWithMessage:@"key_export_success" withTitle:@"key_export_success_title"];
            return;
        }
    }
    [HXOUI showErrorAlertWithMessage:@"key_export_failed" withTitle:@"key_export_failed_title"];
}

- (void) exportPrivateKeyPressed: (id) sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"key_export_private_safety_question", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"key_export_confirm_btn_title", nil)
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetExportPrivateKey;
    [sheet showInView: self.view];
}

- (void) doExportPrivateKey {
    NSData * myKeyBits;
    NSURL * myUrl;
    if (_mode == ProfileViewModeMyProfile) {
        myKeyBits = [[CCRSA sharedInstance] getPrivateKeyBits];
        myUrl = [UserProfile getKeyFileURLWithKeyTypeName:@"ownpubkey" forUser:[[self getModelObject] nickName] withKeyId:self.contact.publicKeyId];
    }
    if (myKeyBits != nil) {
        NSString * exportStuff = [CCRSA makePEMFormattedPrivateKey:myKeyBits];
        NSError * myError = nil;
        [[UIPasteboard generalPasteboard] setString:exportStuff];
        //[exportStuff writeToURL:myUrl atomically:NO encoding:NSUTF8StringEncoding error:&myError];
        if (myError== nil) {
            [HXOUI showErrorAlertWithMessage:@"key_export_success" withTitle:@"key_export_success_title"];
            return;
        }
    }
    [HXOUI showErrorAlertWithMessage:@"key_export_failed" withTitle:@"key_export_failed_title"];
}

- (void) doImportPublicKey {
    NSString * myKeyText = [UIPasteboard generalPasteboard].string;
    NSData * myKeyBits = [CCRSA extractPublicKeyBitsFromPEM:myKeyText];
    if (myKeyBits != nil) {
        if (_mode == ProfileViewModeMyProfile) {
            // set public key of some peer
            if ([[CCRSA sharedInstance] addPublicKeyBits:myKeyBits withTag:[[CCRSA sharedInstance] publicTagForPeer:self.contact.clientId]]) {
                self.contact.publicKeyString = [myKeyBits asBase64EncodedString];
                [HXOUI showErrorAlertWithMessage:@"key_import_success" withTitle:@"key_import_success_title"];
                return;
            }
        } else {
            if ([[CCRSA sharedInstance] addPublicKeyBits:myKeyBits]) {
                [HXOUI showErrorAlertWithMessage:@"key_import_success" withTitle:@"key_import_success_title"];
                return;
            }
        }
    }
    [HXOUI showErrorAlertWithMessage:@"key_import_failed" withTitle:@"key_import_failed_title"];
}

- (void) doImportPrivateKey {
    NSString * myKeyText = [UIPasteboard generalPasteboard].string;
    NSData * myKeyBits = [CCRSA extractPrivateKeyBitsFromPEM:myKeyText];
    if (myKeyBits != nil) {
        if ([[CCRSA sharedInstance] addPrivateKeyBits:myKeyBits]) {
            [HXOUI showErrorAlertWithMessage:@"key_import_success" withTitle:@"key_import_success_title"];
            return;
        }
    }
    [HXOUI showErrorAlertWithMessage:@"key_import_failed" withTitle:@"key_import_failed_title"];
}


- (void) importCredentialsPressed: (id) sender {

    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"credentials_import_safety_question", nil)
                                                    delegate: self
                                           cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                      destructiveButtonTitle: NSLocalizedString(@"credentials_key_import_confirm_btn_title", nil)
                                           otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetImportCredentials;
    [sheet showInView: self.view];
}

- (void) deleteCredentialsFilePressed: (id) sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"credentials_file_delete_safety_question", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                               otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetDeleteCredentialsFile;
    [sheet showInView: self.view];
}
    
- (void) deleteCredentialsPressed: (id) sender {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"credentials_delete_safety_question", nil)
                                                    delegate: self
                                           cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                      destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                           otherButtonTitles: nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    sheet.tag = kActionSheetDeleteCredentialsLate;
    [sheet showInView: self.view];
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
        self.itemsChanged[@"avatar"] = @YES;
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
    return NSLocalizedString(@"profile_avatar_option_sheet_title", "Profile View Avatar Chooser Action Sheet Title");
}

- (void) prependAdditionalActionButtons:(UIActionSheet *)actionSheet {
    if (_avatarItem.currentValue != nil) {
        actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle: NSLocalizedString(@"profile_avatar_option_delete_btn_title", nil)];
    }
}

- (void) additionalButtonPressed:(NSUInteger)buttonIndex {
    // delete avatarImage
    [self updateAvatar: nil];
}

- (void)performKeypairRenewal {
    [[CCRSA sharedInstance] cloneKeyPairKeys];
    [[CCRSA sharedInstance] cleanKeyPairKeys];
}

- (void) renewKeypairPressed: (id) sender {
    //NSLog(@"renewKeypairPressed, sender=%@",sender);
    _renewKeypairRequested = !_renewKeypairRequested;
    _renewKeyPairItem.editLabel = _renewKeyPairItem.currentValue = [self renewKeypairButtonTitle];
    [self.tableView beginUpdates];
    [(UserDefaultsCell*)[self.tableView cellForRowAtIndexPath:sender] configure: _renewKeyPairItem];
    [self.tableView endUpdates];
}
    
- (void) verifyPublicKeyPressed: (id) sender {
    NSLog(@"verifyPublicKeyPressed");
    if (self.contact.verifiedKey == nil || ![self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        self.contact.verifiedKey = self.contact.publicKey;
    } else {
        self.contact.verifiedKey = nil;
    }
    [self.tableView beginUpdates];
    [(UserDefaultsCell*)[self.tableView cellForRowAtIndexPath:sender] configure: _verifyPublicKeyItem];
    //[(UserDefaultsCell*)[self.tableView cellForRowAtIndexPath:sender] configure: _fingerprintItem];
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


