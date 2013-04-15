//
//  ProfileViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

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

static const CGFloat kProfileEditAnimationDuration = 0.5;


@interface ProfileItem : NSObject <UserDefaultsCellTextInputDelegate>

@property (nonatomic,strong) UIImage  *     icon;
@property (nonatomic,strong) NSString *     valueKey; // used to access the model
@property (nonatomic,strong) NSString *     currentValue;
@property (nonatomic,strong) NSString *     editLabel;
@property (nonatomic,strong) NSString *     cellIdentifier;
@property (nonatomic,strong) NSString *     placeholder;
@property (nonatomic,assign) UIKeyboardType keyboardType;
@property (nonatomic,assign) BOOL           required;
@property (nonatomic,assign) BOOL           valid;

@end

@interface AvatarItem : NSObject

@property (nonatomic,strong) UIImage*  image;
@property (nonatomic,strong) NSString* valueKey;
@property (nonatomic,strong) NSString* contactKey;

@end

@interface ProfileViewController ()

@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, readonly) NSPredicate * hasValuePredicate;

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
    } else if (self.contact != nil) {
        _mode = ProfileViewModeContactProfile;
    } else if ([self.parentViewController isKindOfClass: [UINavigationController class]]) {
        _mode = ProfileViewModeMyProfile;
    } else {
        NSLog(@"ProfileViewController viewWillAppear: Unknown mode");
    }
    [self setupNavigationButtons: _mode];

    [self populateValues];
}

- (NSArray*) populateValues {
    id modelObject = _mode == ProfileViewModeContactProfile ? self.contact : [HTUserDefaults standardUserDefaults];
    _avatarItem.image = [UIImage imageWithData: [modelObject valueForKey: _avatarItem.valueKey]];
    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [modelObject valueForKey: item.valueKey];
    }
    return [self filterItems: NO];
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
}

- (void) setupNavigationButtons: (ProfileViewMode) mode {
    switch (mode) {
        case ProfileViewModeFirstRun:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.navigationItem.leftBarButtonItem = nil;
            break;
        case ProfileViewModeMyProfile:
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
            self.navigationItem.leftBarButtonItem = self.hoccerTalkMenuButton;
            break;
        case ProfileViewModeContactProfile:
            self.navigationItem.rightBarButtonItem = nil;
            //self.navigationItem.leftBarButtonItem = self.hoccerTalkMenuButton; // TODO: back button
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
    UITableViewCell * cell = nil;
    if (indexPath.section == 0) {
        cell = [self dequeueReusableCellOfClass: [UserDefaultsCellAvatarPicker class] forIndexPath: indexPath];
        UserDefaultsCellAvatarPicker * avatarCell = (UserDefaultsCellAvatarPicker*)cell;
        [self configureAvatarCell: avatarCell withItem: _avatarItem atIndexPath: indexPath];
    } else {
        ProfileItem * item = (ProfileItem*)_items[indexPath.section][indexPath.row];
        if ([item.cellIdentifier isEqualToString: [UserDefaultsCellTextInput reuseIdentifier]]) {
            cell = [self dequeueReusableCellOfClass: [UserDefaultsCellTextInput class] forIndexPath: indexPath];
            [self configureTextInputCell: (UserDefaultsCellTextInput*)cell withItem: item atIndexPath: indexPath];
        } else if ([item.cellIdentifier isEqualToString: [UserDefaultsCellDisclosure reuseIdentifier]]) {
            cell = [self dequeueReusableCellOfClass: [UserDefaultsCellDisclosure class] forIndexPath: indexPath];
            [self configureDisclosureCell: (UserDefaultsCellDisclosure*)cell withItem: item atIndexPath: indexPath];
        } else {
            NSLog(@"ProfileViewController cellForRowAtIndexPath: unhandled cell type %@", item.cellIdentifier);
        }
    }
    return cell;
}

- (void) configureCell: (UserDefaultsCell*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    cell.imageView.image = item.icon;
}

- (void) configureAvatarCell: (UserDefaultsCellAvatarPicker*) cell withItem: (AvatarItem*) item atIndexPath: (NSIndexPath*) indexPath {
    cell.avatar.image = _avatarItem.image;
    if (cell.avatar.defaultImage == nil) {
        cell.avatar.defaultImage = [UIImage imageNamed: @"avatar_default_contact_large"];
    }
    [cell.avatar addTarget: self action: @selector(avatarTapped:) forControlEvents: UIControlEventTouchUpInside];
}

- (void) configureTextInputCell: (UserDefaultsCellTextInput*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    NSString * value = item.currentValue;
    cell.textField.text = value;
    cell.textField.placeholder = item.placeholder;
    cell.delegate = item;
    cell.editLabel = item.editLabel;

    [self configureCell: cell withItem: item atIndexPath: indexPath];

    cell.textField.keyboardType = item.keyboardType;
}

- (void) configureDisclosureCell: (UserDefaultsCellDisclosure*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    [self configureCell: cell withItem: item atIndexPath: indexPath];
    cell.editLabel = item.editLabel;
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
    _avatarItem = [[AvatarItem alloc] init];
    _avatarItem.valueKey = kHTAvatar;
    _avatarItem.contactKey = @"avatar";

    _allProfileItems = [[NSMutableArray alloc] init];
    
    ProfileItem * nickNameItem = [[ProfileItem alloc] init];
    nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    nickNameItem.valueKey = kHTNickName;
    nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    nickNameItem.placeholder = NSLocalizedString(@"profile_name_placeholder", @"Profile Placeholder Nick Name");
    nickNameItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    nickNameItem.keyboardType = UIKeyboardTypeDefault;
    nickNameItem.required = YES;
    [_allProfileItems addObject: nickNameItem];

    ProfileItem * clientIdItem = [[ProfileItem alloc] init];
    //nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    clientIdItem.valueKey = kHTClientId;
    clientIdItem.editLabel = @"Client Id";
    clientIdItem.placeholder = @"Your Client Id";
    clientIdItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    clientIdItem.keyboardType = UIKeyboardTypeDefault;
    clientIdItem.required = YES;
    [_allProfileItems addObject: clientIdItem];

    ProfileItem * phoneItem = [[ProfileItem alloc] init];
    phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
    phoneItem.valueKey = @"phoneNumber";
    phoneItem.editLabel = NSLocalizedString(@"profile_phone_label", nil);
    phoneItem.placeholder = NSLocalizedString(@"profile_phone_placeholder", nil);
    phoneItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    phoneItem.keyboardType = UIKeyboardTypePhonePad;
    [_allProfileItems addObject: phoneItem];

    ProfileItem * mailItem = [[ProfileItem alloc] init];
    mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
    mailItem.valueKey = @"mailAddress";
    mailItem.editLabel = NSLocalizedString(@"profile_mail_label",nil);
    mailItem.placeholder = NSLocalizedString(@"profile_mail_placeholder", nil);
    mailItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    mailItem.keyboardType = UIKeyboardTypeEmailAddress;
    [_allProfileItems addObject: mailItem];

    ProfileItem * twitterItem = [[ProfileItem alloc] init];
    twitterItem.icon = [UIImage imageNamed: @"icon_profile-twitter"];
    twitterItem.valueKey = @"twitterName";
    twitterItem.editLabel = NSLocalizedString(@"profile_twitter_label", nil);
    twitterItem.placeholder = NSLocalizedString(@"profile_twitter_placeholder", nil);
    twitterItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: twitterItem];

    ProfileItem * facebookItem = [[ProfileItem alloc] init];
    facebookItem.icon = [UIImage imageNamed: @"icon_profile-facebook"];
    facebookItem.valueKey = @"facebookName";
    facebookItem.editLabel = NSLocalizedString(@"profile_facebook_label", nil);
    facebookItem.placeholder = NSLocalizedString(@"profile_facebook_placeholder", nil);
    facebookItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: facebookItem];

    ProfileItem * googlePlusItem = [[ProfileItem alloc] init];
    googlePlusItem.icon = [UIImage imageNamed: @"icon_profile-googleplus"];
    googlePlusItem.valueKey = @"googlePlusName";
    googlePlusItem.editLabel = NSLocalizedString(@"profile_google_plus_label", nil);
    googlePlusItem.placeholder = NSLocalizedString(@"profile_google_plus_placeholder", nil);
    googlePlusItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: googlePlusItem];

    ProfileItem * githubItem = [[ProfileItem alloc] init];
    githubItem.icon = [UIImage imageNamed: @"icon_profile-octocat"];
    githubItem.valueKey = @"githubName";
    githubItem.editLabel = NSLocalizedString(@"profile_github_label", nil);
    githubItem.placeholder = NSLocalizedString(@"profile_github_placeholder", nil);
    githubItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: githubItem];

    for (ProfileItem* item in _allProfileItems) {
        [item addObserver: self forKeyPath: @"valid" options: NSKeyValueObservingOptionNew context: nil];
    }

    return [self populateValues];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString: @"valid"]) {
        [self validateItems];
    }
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
    return @[ @[_avatarItem], items];
}

@synthesize hasValuePredicate = _hasValuePredicate;
- (NSPredicate*) hasValuePredicate {
    if (_hasValuePredicate == nil) {
        _hasValuePredicate = [NSPredicate predicateWithFormat: @"currentValue != nil AND currentValue != ''"];
    }
    return _hasValuePredicate;
}


- (void) saveProfile {
    // TODO: proper size handling
    CGFloat scale;
    if (_avatarItem.image.size.height > _avatarItem.image.size.width) {
        scale = 128.0 / _avatarItem.image.size.width;
    } else {
        scale = 128.0 / _avatarItem.image.size.height;
    }
    CGSize size = CGSizeMake(_avatarItem.image.size.width * scale, _avatarItem.image.size.height * scale);
    [[HTUserDefaults standardUserDefaults] setValue: UIImagePNGRepresentation([_avatarItem.image imageScaledToSize: size]) forKey: _avatarItem.valueKey];
    for (ProfileItem* item in _allProfileItems) {
        if (item.currentValue != nil && ! [item.currentValue isEqual: @""]) {
            [[HTUserDefaults standardUserDefaults] setValue: item.currentValue forKey: item.valueKey];
        }
    }

    if ( ! [[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        NSLog(@"==================== WARNING: Client Id generation disabled ==============");
        //[[HTUserDefaults standardUserDefaults] setValue: [NSString stringWithUUID] forKey: kHTClientId];
        [[HTUserDefaults standardUserDefaults] setBool: YES forKey: kHTFirstRunDone];
        [(AppDelegate*)[[UIApplication sharedApplication] delegate] setupDone];
        [self dismissModalViewControllerAnimated: YES];
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
    _avatarItem.image = image;
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: 0 inSection: 0];
    UserDefaultsCellAvatarPicker * cell = (UserDefaultsCellAvatarPicker*)[self.tableView cellForRowAtIndexPath: indexPath];
    [self.tableView beginUpdates];
    [self configureAvatarCell: cell withItem: _avatarItem atIndexPath: indexPath];
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
    if (_avatarItem.image != nil) {
        actionSheet.destructiveButtonIndex = [actionSheet addButtonWithTitle: NSLocalizedString(@"profile_delete_avatar_button_title", nil)];
    }
}

- (void) additionalButtonPressed:(NSUInteger)buttonIndex {
    // delete avatarImage
    [self updateAvatar: nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void) dealloc {
    for (ProfileItem* item in _allProfileItems) {
        [item removeObserver: self forKeyPath: @"valid"];
    }
}

@end


@implementation ProfileItem

- (id) init {
    self = [super init];
    if (self != nil) {
        self.valid = YES;
    }
    return self;
}

- (void) setRequired:(BOOL)required {
    _required = required;
    if (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""])) {
        self.valid = NO;
    }
}

- (void) setCurrentValue:(NSString *)currentValue {
    _currentValue = currentValue;
    if (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""])) {
        self.valid = NO;
    }
}

- (BOOL) validateTextField:(UITextField *)textField {
    self.currentValue = textField.text;
    if (self.required && ( textField.text == nil || [textField.text isEqualToString: @""])) {
        self.valid = NO;
    } else {
        self.valid = YES;
    }
    return self.valid;
}
@end

@implementation AvatarItem
@end
