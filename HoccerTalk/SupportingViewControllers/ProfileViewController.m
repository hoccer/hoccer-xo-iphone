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

- (NSString*) itemsPlistFileName {
    return @"ProfileItems";
}

- (void) viewDidLoad {
    [super viewDidLoad];

    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
        [self setEditing: YES animated: YES];
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
        ProfileItem * item = (ProfileItem*)_profileItems[indexPath.row];
        cell = [self dequeueReusableCellOfClass: [UserDefaultsCellTextInput class] forIndexPath: indexPath];
        if ([item.cellIdentifier isEqualToString: [UserDefaultsCellTextInput reuseIdentifier]]) {
            [self configureTextCell: (UserDefaultsCellTextInput*)cell withItem: item atIndexPath: indexPath];
        } else {
            NSLog(@"ProfileViewController cellForRowAtIndexPath: unhandled cell type %@", item.cellIdentifier);
        }
    }
    return cell;
}

- (void) configureTextCell: (UserDefaultsCellTextInput*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    NSString * value = item.currentValue;
    cell.imageView.image = item.icon;
    cell.textField.text = value;
    cell.textField.enabled = _editing;
    cell.textField.alpha = _editing ? 1.0 : 0.0;
    cell.textField.placeholder = item.placeholder;
    cell.textField.tag = indexPath.row; // XXX
    cell.textInputBackground.alpha = _editing ? 1.0 : 0.0;

    if (_editing) {
        cell.textLabel.text = item.editLabel;
        cell.textLabel.alpha = 1.0;
    } else {
        if (value != nil && [value length] > 0) {
            cell.textLabel.text = value;
            cell.textLabel.alpha = 1.0;
        } else {
            cell.textLabel.text = item.placeholder;
            cell.textLabel.alpha = 0.5;
        }
    }
    
    cell.textField.keyboardType = item.keyboardType;
    if (cell.textInputBackground.image == nil) {
        cell.textInputBackground.image = [AssetStore stretchableImageNamed: @"profile_text_input_bg" withLeftCapWidth:3 topCapHeight:3];
        cell.textInputBackground.frame = CGRectInset(cell.textField.frame, -8, 2);
        cell.textField.delegate = self;
        cell.textField.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor colorWithWhite: 0.25 alpha: 1.0];
        cell.textLabel.backgroundColor = [UIColor clearColor];
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

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    // do not call super class
    if (_editing == editing ) {
        return;
    }
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = YES;
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone:)];
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
            }
        }
    } completion:^(BOOL finished) {
        _editing = ! _editing;
    }];
    [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            if ([cell isKindOfClass: [UserDefaultsCellTextInput class]]) {
                UserDefaultsCellTextInput * profileCell = (UserDefaultsCellTextInput*)cell;
                profileCell.textLabel.alpha = 0.0;
            }
        }
    } completion:^(BOOL finished) {
        int index = 0;
        NSArray * indexPaths = self.tableView.indexPathsForVisibleRows;
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            ProfileItem * item = _profileItems[((NSIndexPath*)indexPaths[index++]).row];
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
            }
        }
        [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
            for (UITableViewCell * cell in self.tableView.visibleCells) {
                if ([cell isKindOfClass: [UserDefaultsCellTextInput class]]) {
                    UserDefaultsCellTextInput * profileCell = (UserDefaultsCellTextInput*)cell;
                    profileCell.textLabel.alpha = [profileCell.textLabel.text isEqualToString: profileCell.textField.placeholder] ? 0.5 : 1.0;
                }
            }
        }];
    }];

}

- (IBAction)onCancel:(id)sender {
    [self reloadProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (IBAction)onDone:(id)sender {
    [self saveProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (NSArray*) populateItems {

    _avatarItem = [[AvatarItem alloc] init];
    _avatarItem.userDefaultsKey = kHTAvatarImage;

    _profileItems = [[NSMutableArray alloc] init];

    ProfileItem * nickNameItem = [[ProfileItem alloc] init];
    nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
    nickNameItem.userDefaultsKey = kHTNickName;
    nickNameItem.editLabel = NSLocalizedString(@"profile_name_label", @"Profile Edit Label Nick Name");
    nickNameItem.placeholder = NSLocalizedString(@"profile_name_placeholder", @"Profile Placeholder Nick Name");
    nickNameItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    nickNameItem.keyboardType = UIKeyboardTypeDefault;
    [_profileItems addObject: nickNameItem];

    ProfileItem * phoneItem = [[ProfileItem alloc] init];
    phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
    phoneItem.userDefaultsKey = @"phoneNumber";
    phoneItem.editLabel = NSLocalizedString(@"profile_phone_label", @"Profile Edit Label Phone Number");
    phoneItem.placeholder = NSLocalizedString(@"profile_phone_placeholder", @"Profile Placeholder Phone Number");
    phoneItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    phoneItem.keyboardType = UIKeyboardTypePhonePad;
    [_profileItems addObject: phoneItem];

    ProfileItem * mailItem = [[ProfileItem alloc] init];
    mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
    mailItem.userDefaultsKey = @"mailAddress";
    mailItem.editLabel = NSLocalizedString(@"profile_mail_label", @"Profile Edit Label Mail Address");
    mailItem.placeholder = NSLocalizedString(@"profile_mail_placeholder", @"Profile Placeholder MAil Address");
    mailItem.cellIdentifier = [UserDefaultsCellTextInput reuseIdentifier];
    mailItem.keyboardType = UIKeyboardTypeEmailAddress;
    [_profileItems addObject: mailItem];

    _avatarItem.image = [UIImage imageWithData: [[HTUserDefaults standardUserDefaults] valueForKey: _avatarItem.userDefaultsKey]];
    for (ProfileItem* item in _profileItems) {
        item.currentValue = [[HTUserDefaults standardUserDefaults] valueForKey: item.userDefaultsKey];
    }
    return @[ @[_avatarItem], _profileItems];
}

- (void) saveProfile {
    [self.tableView endEditing: NO];
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
        NSLog(@"saving %@ as %@", item.currentValue, item.userDefaultsKey);
        [[HTUserDefaults standardUserDefaults] setValue: item.currentValue forKey: item.userDefaultsKey];
    }

    if ( ! [[HTUserDefaults standardUserDefaults] boolForKey: kHTFirstRunDone]) {
        [[HTUserDefaults standardUserDefaults] setValue: [NSString stringWithUUID] forKey: kHTClientId];
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
    } else {
        NSLog(@"avatar chooser cancel");
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
