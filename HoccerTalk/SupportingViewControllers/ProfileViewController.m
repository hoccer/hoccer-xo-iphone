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

static const CGFloat kProfileEditAnimationDuration = 0.5;

@interface ProfileItem : NSObject

@property (nonatomic,strong) UIImage  * icon;
@property (nonatomic,strong) NSString * userDefaultsKey;
@property (nonatomic,strong) NSString * currentValue;
@property (nonatomic,strong) NSString * editLabel;
@property (nonatomic,strong) NSString * cellIdentifier;
@property (nonatomic,strong) NSString * placeholder;
@property (nonatomic,assign) UIKeyboardType keyboardType;

@end

@interface AvatarItem : NSObject

@property (nonatomic,strong) UIImage*  image;
@property (nonatomic,strong) NSString* userDefaultsKey;

@end

@interface ProfileViewController ()

@property (strong, readonly) AttachmentPickerController* attachmentPicker;

@end

@implementation ProfileViewController

@synthesize attachmentPicker = _attachmentPicker;

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _editing = NO;
    }
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];

    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.editButtonItem.target = self;
    self.editButtonItem.action = @selector(enableEditing);
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];

    if ([[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        self.navigationItem.leftBarButtonItem =  self.hoccerTalkMenuButton;
    }
    //[self populateItems];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    if ( ! [[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        [self enableEditing];
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
        avatarCell.avatar.image = _avatarItem.image;
        avatarCell.avatar.enabled = _editing;
        if (avatarCell.avatar.defaultImage == nil) {
            avatarCell.avatar.defaultImage = [UIImage imageNamed: @"avatar_default_contact_large"];
        }
        [avatarCell.avatar addTarget: self action: @selector(avatarTapped:) forControlEvents: UIControlEventTouchUpInside];
    } else {
        ProfileItem * item = (ProfileItem*)_items[indexPath.section][indexPath.row];
        if ([item.cellIdentifier isEqualToString: [UserDefaultsCellTextInput reuseIdentifier]]) {
            cell = [self dequeueReusableCellOfClass: [UserDefaultsCellTextInput class] forIndexPath: indexPath];
            [self configureTextCell: (UserDefaultsCellTextInput*)cell withItem: item atIndexPath: indexPath];
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
    if (_editing) {
        cell.textLabel.text = item.editLabel;
        cell.textLabel.alpha = 1.0;
    } else {
        if (item.currentValue != nil && [item.currentValue length] > 0) {
            cell.textLabel.text = item.currentValue;
            cell.textLabel.alpha = 1.0;
        } else {
            cell.textLabel.text = item.placeholder;
            cell.textLabel.alpha = 0.5;
        }
    }
}

- (void) configureTextCell: (UserDefaultsCellTextInput*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    NSString * value = item.currentValue;
    cell.textField.text = value;
    cell.textField.enabled = _editing;
    cell.textField.alpha = _editing ? 1.0 : 0.0;
    cell.textField.placeholder = item.placeholder;
    cell.textField.tag = indexPath.row; // XXX
    cell.textInputBackground.alpha = _editing ? 1.0 : 0.0;

    [self configureCell: cell withItem: item atIndexPath: indexPath];

    cell.textField.keyboardType = item.keyboardType;
    if (cell.textInputBackground.image == nil) {
        cell.textInputBackground.image = [AssetStore stretchableImageNamed: @"profile_text_input_bg" withLeftCapWidth:3 topCapHeight:3];
        cell.textInputBackground.frame = CGRectInset(cell.textField.frame, -8, 2);
        cell.textField.delegate = self;
        cell.textField.backgroundColor = [UIColor clearColor];
    }
}

- (void) configureDisclosureCell: (UserDefaultsCellDisclosure*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    [self configureCell: cell withItem: item atIndexPath: indexPath];
    if (_editing) {
        if (cell.accessoryView != nil) {
            cell.accessoryView.hidden = NO; // XXX alpha does not work???
        }
    } else {
        if (cell.accessoryView != nil) {
            cell.accessoryView.hidden = YES; // XXX alpha does not work???
        }
    }
}


- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    ((ProfileItem*)_profileItems[textField.tag]).currentValue = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void) enableEditing {
    // do not call super class
    _items = [self filterItems:  YES];
    [self.tableView reloadData];

    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = YES;
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(onDone:)];
    if ([[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
        [self.navigationItem setLeftBarButtonItem: cancelButton animated:YES];
    }
    [self.navigationItem setRightBarButtonItem: doneButton animated:YES];

    [self animateTableCells];
}

- (void) animateTableCells {
    CGFloat alpha = _editing ? 0.0 : 1.0;
    [UIView animateWithDuration: kProfileEditAnimationDuration animations:^{
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            if ([cell isKindOfClass: [UserDefaultsCellTextInput class]]) {
                UserDefaultsCellTextInput * profileCell = (UserDefaultsCellTextInput*)cell;
                profileCell.textField.alpha = alpha;
                profileCell.textField.enabled = ! _editing;
                profileCell.textInputBackground.alpha = alpha;
            } else if ([cell isKindOfClass: [UserDefaultsCellAvatarPicker class]]) {
                UserDefaultsCellAvatarPicker * avatarCell = (UserDefaultsCellAvatarPicker*) cell;
                avatarCell.avatar.enabled = ! _editing;
                avatarCell.avatar.outerShadowColor = _editing ? [UIColor whiteColor] : [UIColor orangeColor];
            } else if ([cell isKindOfClass: [UserDefaultsCellDisclosure class]]) {
                UserDefaultsCellDisclosure * disclosureCell = (UserDefaultsCellDisclosure*) cell;
                disclosureCell.accessoryView.hidden = _editing;
            }
        }
    } completion:^(BOOL finished) {
        _editing = ! _editing;
    }];
    [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            if ([cell isKindOfClass: [UserDefaultsCellTextInput class]] ||
                [cell isKindOfClass: [UserDefaultsCellDisclosure class]])
            {
                cell.textLabel.alpha = 0.0;
            }

        }
    } completion:^(BOOL finished) {
        int index = 0;
        NSArray * indexPaths = self.tableView.indexPathsForVisibleRows;
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            NSIndexPath * indexPath = (NSIndexPath*)indexPaths[index++];
            ProfileItem * item = _items[indexPath.section][indexPath.row];
            if ([cell isKindOfClass: [UserDefaultsCellTextInput class]]) {
                UserDefaultsCellTextInput * profileCell = (UserDefaultsCellTextInput*)cell;
                if (_editing) {
                    if (profileCell.textField.text == nil || [profileCell.textField.text isEqualToString: @""]) {
                        profileCell.textLabel.text = profileCell.textField.placeholder;
                    } else {
                         profileCell.textLabel.text = profileCell.textField.text;
                    }
                } else {
                    profileCell.textLabel.text = item.editLabel;
                }
            } else if ([cell isKindOfClass: [UserDefaultsCellDisclosure class]]) {
                UserDefaultsCellDisclosure * profileCell = (UserDefaultsCellDisclosure*)cell;
                if (_editing) {
                    if (item.currentValue == nil) {
                        profileCell.textLabel.text = item.placeholder;
                    } else {
                        profileCell.textLabel.text = item.currentValue;
                    }
                } else {
                    profileCell.textLabel.text = item.editLabel;
                }
            }

        }
        [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
            NSArray * indexPaths = self.tableView.indexPathsForVisibleRows;
            int index = 0;
            for (UITableViewCell * cell in self.tableView.visibleCells) {
                ProfileItem * item = _profileItems[((NSIndexPath*)indexPaths[index++]).row];
                if ([cell isKindOfClass: [UserDefaultsCellTextInput class]] ||
                    [cell isKindOfClass: [UserDefaultsCellDisclosure class]])
                {
                    UserDefaultsCellTextInput * profileCell = (UserDefaultsCellTextInput*)cell;
                    profileCell.textLabel.alpha = [profileCell.textLabel.text isEqualToString: item.placeholder] ? 0.5 : 1.0;
                }
            }
        }];
    }];

}

- (IBAction)onCancel:(id)sender {
    _items = [self filterItems:  NO];
    [self.tableView reloadData]; // TODO: get rid of reloadData

    [self reloadProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (IBAction)onDone:(id)sender {

    _items = [self filterItems:  NO];
    [self.tableView reloadData]; // TODO: get rid of reloadData

    [self saveProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (NSArray*) populateItems {

    _avatarItem = [[AvatarItem alloc] init];
    _avatarItem.userDefaultsKey = kHTAvatarImage;

    _allProfileItems = [[NSMutableArray alloc] init];

    ProfileItem * nickNameItem = [[ProfileItem alloc] init];
    nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    nickNameItem.userDefaultsKey = kHTNickName;
    nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    nickNameItem.placeholder = NSLocalizedString(@"profile_name_placeholder", @"Profile Placeholder Nick Name");
    nickNameItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    nickNameItem.keyboardType = UIKeyboardTypeDefault;
    [_allProfileItems addObject: nickNameItem];

    ProfileItem * clientIdItem = [[ProfileItem alloc] init];
    //nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    clientIdItem.userDefaultsKey = kHTClientId;
    clientIdItem.editLabel = @"Client Id";
    clientIdItem.placeholder = @"Your Client Id";
    clientIdItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    clientIdItem.keyboardType = UIKeyboardTypeDefault;
    [_allProfileItems addObject: clientIdItem];

    ProfileItem * phoneItem = [[ProfileItem alloc] init];
    phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
    phoneItem.userDefaultsKey = @"phoneNumber";
    phoneItem.editLabel = NSLocalizedString(@"profile_phone_label", nil);
    phoneItem.placeholder = NSLocalizedString(@"profile_phone_placeholder", nil);
    phoneItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    phoneItem.keyboardType = UIKeyboardTypePhonePad;
    [_allProfileItems addObject: phoneItem];

    ProfileItem * mailItem = [[ProfileItem alloc] init];
    mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
    mailItem.userDefaultsKey = @"mailAddress";
    mailItem.editLabel = NSLocalizedString(@"profile_mail_label",nil);
    mailItem.placeholder = NSLocalizedString(@"profile_mail_placeholder", nil);
    mailItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    mailItem.keyboardType = UIKeyboardTypeEmailAddress;
    [_allProfileItems addObject: mailItem];

    ProfileItem * twitterItem = [[ProfileItem alloc] init];
    twitterItem.icon = [UIImage imageNamed: @"icon_profile-twitter"];
    twitterItem.userDefaultsKey = @"twitterName";
    twitterItem.editLabel = NSLocalizedString(@"profile_twitter_label", nil);
    twitterItem.placeholder = NSLocalizedString(@"profile_twitter_placeholder", nil);
    twitterItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: twitterItem];

    ProfileItem * facebookItem = [[ProfileItem alloc] init];
    facebookItem.icon = [UIImage imageNamed: @"icon_profile-facebook"];
    facebookItem.userDefaultsKey = @"facebookName";
    facebookItem.editLabel = NSLocalizedString(@"profile_facebook_label", nil);
    facebookItem.placeholder = NSLocalizedString(@"profile_facebook_placeholder", nil);
    facebookItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: facebookItem];

    ProfileItem * googlePlusItem = [[ProfileItem alloc] init];
    googlePlusItem.icon = [UIImage imageNamed: @"icon_profile-googleplus"];
    googlePlusItem.userDefaultsKey = @"googlePlusName";
    googlePlusItem.editLabel = NSLocalizedString(@"profile_google_plus_label", nil);
    googlePlusItem.placeholder = NSLocalizedString(@"profile_google_plus_placeholder", nil);
    googlePlusItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: googlePlusItem];

    ProfileItem * githubItem = [[ProfileItem alloc] init];
    githubItem.icon = [UIImage imageNamed: @"icon_profile-octocat"];
    githubItem.userDefaultsKey = @"githubName";
    githubItem.editLabel = NSLocalizedString(@"profile_github_label", nil);
    githubItem.placeholder = NSLocalizedString(@"profile_github_placeholder", nil);
    githubItem.cellIdentifier = [UserDefaultsCellDisclosure reuseIdentifier];
    [_allProfileItems addObject: githubItem];

    _avatarItem.image = [UIImage imageWithData: [[HTUserDefaults standardUserDefaults] valueForKey: _avatarItem.userDefaultsKey]];
    for (ProfileItem* item in _allProfileItems) {
        item.currentValue = [[HTUserDefaults standardUserDefaults] valueForKey: item.userDefaultsKey];
    }
    return [self filterItems: _editing];
}

- (NSArray*) filterItems: (BOOL) editing {
    NSArray * items;
    if (editing) {
        items = _allProfileItems;
    } else {
        NSPredicate * itemsWithValues = [NSPredicate predicateWithFormat: @"currentValue != nil"];
        items = [_allProfileItems filteredArrayUsingPredicate: itemsWithValues];
    }
    return @[ @[_avatarItem], items];
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
    [[HTUserDefaults standardUserDefaults] setValue: UIImagePNGRepresentation([_avatarItem.image imageScaledToSize: size]) forKey: _avatarItem.userDefaultsKey];
    for (ProfileItem* item in _profileItems) {
        [[HTUserDefaults standardUserDefaults] setValue: item.currentValue forKey: item.userDefaultsKey];
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

- (void) reloadProfile {
    //[self populateItems];
    // TODO: this causes a weird artifact in the table background. Not reloading the data causes
    // inconsistencies in the avatar cell... let's be consistent for now and deal with the artifact later
    [self.tableView reloadData];
}

- (void) restoreNonEditButtons {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    [self.navigationItem setLeftBarButtonItem: self.hoccerTalkMenuButton animated:YES];
    [self.navigationItem setRightBarButtonItem: self.editButtonItem animated:YES];
    [NSTimer scheduledTimerWithTimeInterval: 1.0 target:self selector: @selector(makeLeftButtonFixedWidth) userInfo:nil repeats:NO];
}

- (void) makeLeftButtonFixedWidth {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
}

#pragma marl - Avatar Handling

- (IBAction)avatarTapped:(id)sender {
    [self.attachmentPicker showInView: self.view];
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
        _avatarItem.image = image;
        [self.tableView reloadData];
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
    _avatarItem.image = nil;
    [self.tableView reloadData];
}

- (void)viewDidUnload {
    [super viewDidUnload];
}
@end

@implementation ProfileItem
@end

@implementation AvatarItem
@end
