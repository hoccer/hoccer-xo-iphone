//
//  ProfileViewController.h
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AttachmentPickerController.h"

#import "HXOGroupedTableViewController.h"
#import "ProfileDataSource.h"

@class UserDefaultsCellAvatarPicker;
@class UserDefaultsCellTextInput;
@class AvatarItem;
@class Contact;
@class ProfileItem;
@class AppDelegate;
@class ProfileDataSource;

typedef enum ProfileViewModes {
    ProfileViewModeFirstRun,
    ProfileViewModeMyProfile,
    ProfileViewModeContactProfile,

    ProfileViewModeNewGroup,
    ProfileViewModeEditGroup,
    ProfileViewModeShowGroup
} ProfileViewMode;

@interface ProfileViewController : HXOGroupedTableViewController <AttachmentPickerControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate, ProfileDataSourceDelegate>
{
    AvatarItem *          _avatarItem;
    ProfileSection *      _avatarSection;
    
    ProfileItem *         _nickNameItem;
//#ifdef DEBUG
    ProfileSection *      _debugItemsSection;
    ProfileItem *         _clientIdItem;
    ProfileItem *         _groupMembershipsItem;
//#endif
    ProfileSection *      _profileItemsSection;

    ProfileItem *         _chatWithContactItem;
    ProfileItem *         _blockContactItem;
    ProfileSection *      _utilitySection;

    ProfileItem *         _fingerprintItem;
    ProfileItem *         _fingerprintInfoItem;
    ProfileSection *      _fingerprintSection;

    ProfileItem *         _renewKeyPairItem;
    ProfileItem *         _renewKeyPairInfoItem;
    ProfileSection *      _keypairSection;

    ProfileItem *         _deleteContactItem;
    ProfileSection *      _destructiveSection;

    ProfileItem *         _exportCredentialsItem;
    ProfileItem *         _importCredentialsItem;
    ProfileItem *         _deleteCredentialsItem;
    ProfileSection *      _credentialsSection;
    
    NSArray *             _profileItems;
    NSMutableArray *      _allProfileItems;
    ProfileViewMode       _mode;
    BOOL                  _canceled;
    BOOL                  _renewKeypairRequested;
    NSMutableDictionary * _itemsByKeyPath;
    ProfileDataSource *   _profileDataSource;
}


@property (nonatomic,strong) Contact* contact;
@property (strong, readonly) AppDelegate * appDelegate;


- (void) setupNavigationButtons;
- (void) setupContactKVO;
- (IBAction)onCancel:(id)sender;
- (void) populateItems;
- (void) composeProfileItems: (BOOL) editing;
- (void) populateValues;

@end
