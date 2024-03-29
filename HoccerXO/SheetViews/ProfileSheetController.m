//
//  ProfileSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ProfileSheetController.h"
#import "UserProfile.h"
#import "AppDelegate.h"
#import "HXOUI.h"
#import "ModalTaskHUD.h"
#import "ContactListViewController.h"
#import "tab_profile.h"
#import "ImageViewController.h"
#import "HXOLocalization.h"
#import "StudentIdViewController.h"


@interface ProfileSheetController ()

@property (nonatomic, readonly) UserProfile      * userProfile;

@property (nonatomic, readonly) DatasheetSection * credentialsSection;

#if HOCCER_UNIHELD
@property (nonatomic, readonly) DatasheetSection * studentIdSection;
@property (nonatomic, readonly) DatasheetItem * studentIdItem;
#endif

@end

@implementation ProfileSheetController

@synthesize contactCountItem = _contactCountItem;
@synthesize groupCountItem = _groupCountItem;

@synthesize credentialsSection = _credentialsSection;
@synthesize exportCredentialsItem = _exportCredentialsItem;
@synthesize transferCredentialsItem = _transferCredentialsItem;
@synthesize transferArchiveItem = _transferArchiveItem;
@synthesize fetchCredentialsItem = _fetchCredentialsItem;
@synthesize fetchArchiveItem = _fetchArchiveItem;
@synthesize importCredentialsItem = _importCredentialsItem;
@synthesize deleteCredentialsFileItem = _deleteCredentialsFileItem;

@synthesize archiveAllItem = _archiveAllItem;
@synthesize archiveImportItem = _archiveImportItem;
@synthesize deleteAccountItem = _deleteAccountItem;

@synthesize destructiveSection = _destructiveSection;

#if HOCCER_UNIHELD
@synthesize studentIdSection = _studentIdSection;
@synthesize studentIdItem = _studentIdItem;
#endif

- (void) commonInit {
    [super commonInit];

    self.title = @"profile_nav_title";

    self.nicknameItem.enabledMask = DatasheetModeEdit;

    //self.keyItem.visibilityMask = DatasheetModeView;
    self.keyItem.cellIdentifier = @"DatasheetActionCell";

    self.destructiveButton.title = @"credentials_delete_btn_title";
    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(deleteCredentialsPressed:);

    self.isEditable = YES;

}

- (void) awakeFromNib {
    self.inspectedObject = [UserProfile sharedProfile];
}

- (VectorArt*) tabBarIcon {
    return [[tab_profile alloc] init];
}

- (UserProfile*) userProfile {
    return [self.inspectedObject isKindOfClass: [UserProfile class]] ? self.inspectedObject : nil;
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];

    [self.userProfile saveProfile];
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.contactCountItem, self.groupCountItem, self.keyItem];
    return section;
}

- (DatasheetItem*) contactCountItem {
    if (!_contactCountItem) {
        _contactCountItem = [self itemWithIdentifier: @"profile_contact_count" cellIdentifier: @"DatasheetKeyValueCell"];
        _contactCountItem.valuePath = @"contactCount";
        _contactCountItem.accessoryStyle = DatasheetAccessoryDisclosure;
        _contactCountItem.segueIdentifier = @"ShowContacts";
    }
    return _contactCountItem;
}

- (DatasheetItem*) groupCountItem {
    if (!_groupCountItem) {
        _groupCountItem = [self itemWithIdentifier: @"profile_group_count" cellIdentifier: @"DatasheetKeyValueCell"];
        _groupCountItem.valuePath = @"groupCount";
        _groupCountItem.accessoryStyle = DatasheetAccessoryDisclosure;
        _groupCountItem.segueIdentifier = @"ShowContacts";
    }
    return _groupCountItem;
}

- (DatasheetSection*) credentialsSection {
    if ( ! _credentialsSection) {
        _credentialsSection = [DatasheetSection datasheetSectionWithIdentifier: @"credentials_section"];
        _credentialsSection.headerViewIdentifier = @"DatasheetFooterTextView";
        _credentialsSection.items = @[self.exportCredentialsItem,
                                      self.importCredentialsItem,
                                      self.deleteCredentialsFileItem
                                      
#ifdef HOCCER_XO
                                      , self.transferCredentialsItem
#endif
#ifdef HOCCER_CLASSIC
                                      , self.fetchCredentialsItem
                                      , self.fetchArchiveItem
#endif
                                      , self.archiveAllItem
                                      , self.archiveImportItem
                                      , self.transferArchiveItem
                                      ];
    }
    return _credentialsSection;
}

- (void) addUtilitySections:(NSMutableArray *)sections {
    [super addUtilitySections: sections];
#if HOCCER_UNIHELD
    [sections addObject: self.studentIdSection];
#endif
    [sections addObject: self.credentialsSection];
}

#if HOCCER_UNIHELD
- (DatasheetSection*) studentIdSection {
    if ( ! _studentIdSection) {
        _studentIdSection = [DatasheetSection datasheetSectionWithIdentifier: @"uniheld_student_id_section"];
        _studentIdSection.items = @[self.studentIdItem];
    }
    return _studentIdSection;
}

- (DatasheetItem*) studentIdItem {
    if(!_studentIdItem) {
        _studentIdItem = [self itemWithIdentifier: @"uniheld_student_id_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _studentIdItem.target = self;
        _studentIdItem.enabledMask =  DatasheetModeView | DatasheetModeEdit;
        _studentIdItem.accessoryStyle = DatasheetAccessoryDisclosure;
        _studentIdItem.action = @selector(studentIdPressed:);

    }
    return _studentIdItem;
}

- (IBAction) studentIdPressed:(id)sender {
    //NSLog(@"pressed student id");
    if (self.mode == DatasheetModeEdit && [self isItemEnabled: self.studentIdItem]) {
        [self editStudentId];
    } else if ([self studentIdImage]) {
        [(id)self.delegate performSegueWithIdentifier: @"showStudentId" sender: self];
    } else {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: HXOLabelledLocalizedString(@"uniheld_student_id_no_image_alert_title", nil)
                                                         message: HXOLabelledLocalizedString(@"uniheld_student_id_no_image_alert_message", nil)
                                                 completionBlock: ^(NSUInteger buttonIndex, UIAlertView * alertView) {}
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    }
}

- (void) editStudentId {
    [self editImage: [self studentIdImage]
   optionSheetTitle: @"uniheld_student_id_image_option_sheet_title"
 libraryOptionTitle: @"profile_avatar_option_album_btn_title"
  cameraOptionTitle: @"attachment_src_camera_btn_title"
        deleteTitle: @"uniheld_student_id_image_option_delete_btn_title"
       imageHandler: ^(UIImage* image) {
           if (image.imageOrientation != UIImageOrientationUp) {;
               UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
               [image drawInRect:(CGRect){0, 0, image.size}];
               image = UIGraphicsGetImageFromCurrentImageContext();
               UIGraphicsEndImageContext();
           }
           [[NSUserDefaults standardUserDefaults] setObject: UIImagePNGRepresentation(image)
                                                     forKey: @"UniheldStudentIdImage"];
       }
      deleteHandler: ^(){ [self deleteStudentIdImage]; }
       allowEditing: NO];
}

- (UIImage*) studentIdImage {
    NSData* imageData = [[NSUserDefaults standardUserDefaults] objectForKey: @"UniheldStudentIdImage"];
    if (imageData) {

        UIImage * image = [UIImage imageWithData: imageData];
        /*
        if (image.imageOrientation == UIImageOrientationUp) return image;

        UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
        [image drawInRect:(CGRect){0, 0, image.size}];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
*/
        return image;
    }
    return nil;
}

- (void) deleteStudentIdImage {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"UniheldStudentIdImage"];
}

#endif

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.importCredentialsItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    } else if ([item isEqual: self.deleteCredentialsFileItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    } else if ([item isEqual: self.fetchCredentialsItem]) {
        return self.userProfile.foundCredentialsProviderApp && [super isItemVisible: item];
    } else if ([item isEqual: self.deleteAccountItem]) {
        return self.userProfile.hasActiveAccount && [super isItemVisible: item];
    } else if ([item isEqual: self.contactCountItem] || [item isEqual: self.groupCountItem]) {
        return self.userProfile.isRegistered && !self.userProfile.isFirstRun && [super isItemVisible: item];
    }
    
    return [super isItemVisible: item];
}

#pragma mark - Make Archive

- (DatasheetItem*) archiveAllItem {
    if ( ! _archiveAllItem) {
        _archiveAllItem = [self itemWithIdentifier: @"archive_all_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _archiveAllItem.visibilityMask = DatasheetModeEdit;
        _archiveAllItem.target = self;
        _archiveAllItem.action = @selector(archiveAllPressed:);
    }
    return _archiveAllItem;
}

- (void) archiveAllPressed: (id) sender {
    
    
    long long requiredSpace = [AppDelegate estimatedDocumentArchiveSize] * 1.1;
    long long freeSpace = [AppDelegate freeDiskSpace] + [AppDelegate archiveFileSize];
    
    NSLog(@"archiveAllPressed: required %@, free %@",[AppDelegate memoryFormatter:requiredSpace],[AppDelegate memoryFormatter:freeSpace]);
    
    if (requiredSpace > freeSpace) {
        HXOAlertViewCompletionBlock completion2 = ^(NSUInteger buttonIndex, UIAlertView * alertView) {};
        NSString * archiveNotEnoughSpaceMessage = [NSString stringWithFormat:NSLocalizedString(@"archive_export_not_enough_space %@ %@", nil),
                                                   [AppDelegate memoryFormatter:requiredSpace],
                                                   [AppDelegate memoryFormatter:freeSpace]];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_export_not_enough_space_title",nil)
                                                         message: archiveNotEnoughSpaceMessage
                                                 completionBlock: completion2
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
        
    } else {
        
        HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
            if (buttonIndex == actionSheet.destructiveButtonIndex) {
                NSURL* archiveURL = [[AppDelegate.instance applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
                [AppDelegate.instance makeArchive:archiveURL withHandler:^(NSURL* url) {
                    if (url == nil) {
                        [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"archive_failed_message",nil)
                                                             withTitle:NSLocalizedString(@"archive_failed_title",nil)
                                                           withOKBlock:^{
                                                           }];
                    } else {
                        [HXOUI showErrorAlertWithMessageAsync: @"archive_ok_alert_message" withTitle:@"archive_ok_alert_title"];
                    }
                }];
                
            }
        };
        
        UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"archive_safety_question", nil)
                                            completionBlock: completion
                                          cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                     destructiveButtonTitle: NSLocalizedString(@"archive", nil)
                                          otherButtonTitles: nil];
        [sheet showInView: self.delegate.view];
    }
}

#pragma mark - Import & install Archive

- (DatasheetItem*) archiveImportItem {
    if ( ! _archiveImportItem) {
        _archiveImportItem = [self itemWithIdentifier: @"archive_import_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _archiveImportItem.visibilityMask = DatasheetModeEdit;
        _archiveImportItem.target = self;
        _archiveImportItem.action = @selector(archiveImportPressed:);
    }
    return _archiveImportItem;
}

- (void) archiveImportPressed: (id) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            NSURL* archiveURL = [[AppDelegate.instance applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
            [AppDelegate.instance importArchive:archiveURL withHandler:^(BOOL ok) {
                if (!ok) {
                    [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"archive_import_failed_message",nil)
                                                         withTitle:NSLocalizedString(@"archive_import_failed_title",nil)
                                                       withOKBlock:^{
                                                       }];
                } else {
                    [AppDelegate.instance showFatalErrorAlertWithMessage: NSLocalizedString(@"archive_imported_message",nil)
                                                               withTitle:NSLocalizedString(@"archive_imported_title",nil)
                     ];
                }
            }];
            
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"archive_import_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"archive_import_btn_title", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - transfer Archive other app

- (DatasheetItem*) transferArchiveItem {
    if ( ! _transferArchiveItem) {
        _transferArchiveItem = [self itemWithIdentifier: @"archive_transfer_open_with_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _transferArchiveItem.visibilityMask = DatasheetModeEdit;
        _transferArchiveItem.target = self;
        _transferArchiveItem.action = @selector(transferArchivePressed:);
    }
    return _transferArchiveItem;
}

- (void) transferArchivePressed: (id) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            NSURL* archiveURL = [[AppDelegate.instance applicationDocumentsDirectory] URLByAppendingPathComponent: kHXODefaultArchiveName];
            [AppDelegate.instance makeArchive:archiveURL withHandler:^(NSURL* url) {
                if (url == nil) {
                    [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"archive_failed_message",nil)
                                                         withTitle:NSLocalizedString(@"archive_failed_title",nil)
                                                       withOKBlock:^{
                                                       }];
                } else {                    
                    [AppDelegate.instance openWithInteractionController:url withUTI:kHXOTransferArchiveUTI withName:kHXODefaultArchiveName inView:self.delegate.view withController:self.delegate removeFile:YES];
                }
            }];
            
        }
    };
    long long requiredSpace = [AppDelegate estimatedDocumentArchiveSize] * 2.1;
    long long freeSpace = [AppDelegate freeDiskSpace] + [AppDelegate archiveFileSize];
    
    NSLog(@"transferArchive: required %@, free %@",[AppDelegate memoryFormatter:requiredSpace],[AppDelegate memoryFormatter:freeSpace]);
    
    if (requiredSpace > freeSpace) {
        HXOAlertViewCompletionBlock completion2 = ^(NSUInteger buttonIndex, UIAlertView * alertView) {};
        NSString * archiveNotEnoughSpaceMessage = [NSString stringWithFormat:NSLocalizedString(@"archive_transfer_not_enough_space %@ %@", nil),
                                                   [AppDelegate memoryFormatter:requiredSpace],
                                                   [AppDelegate memoryFormatter:freeSpace]];
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"archive_transfer_not_enough_space_title",nil)
                                                         message: archiveNotEnoughSpaceMessage
                                                 completionBlock: completion2
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
        
    } else {
        
        UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"archive_transfer_open_with_safety_question", nil)
                                            completionBlock: completion
                                          cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                     destructiveButtonTitle: NSLocalizedString(@"archive", nil)
                                          otherButtonTitles: nil];
        [sheet showInView: self.delegate.view];
    }
}


#pragma mark - Fetch Archive

- (DatasheetItem*) fetchArchiveItem {
    if ( ! _fetchArchiveItem) {
        _fetchArchiveItem = [self itemWithIdentifier: @"archive_fetch_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _fetchArchiveItem.visibilityMask = DatasheetModeEdit;
        _fetchArchiveItem.dependencyPaths = @[@"foundCredentialsProviderApp"];
        _fetchArchiveItem.target = self;
        _fetchArchiveItem.action = @selector(fetchArchivePressed:);
        
    }
    return _fetchArchiveItem;
}

- (void) fetchArchivePressed: (UIViewController*) sender {
    
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            NSURL * myFetchURL = [UserProfile sharedProfile].fetchArchiveURL;
            if ([[UIApplication sharedApplication] openURL:myFetchURL]) {
                NSLog(@"Credentials openURL returned true");
            } else {
                NSLog(@"Credentials openURL returned false");
            }
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"archive_fetch_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"archive_fetch_confirm_btn_title", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}


#pragma mark - Export Credentials

- (DatasheetItem*) exportCredentialsItem {
    if ( ! _exportCredentialsItem) {
        _exportCredentialsItem = [self itemWithIdentifier: @"credentials_export_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _exportCredentialsItem.visibilityMask = DatasheetModeEdit;
        _exportCredentialsItem.target = self;
        _exportCredentialsItem.action = @selector(exportCredentialsPressed:);
    }
    return _exportCredentialsItem;
}

- (void) exportCredentialsPressed: (id) sender {
    void(^completion)(NSString*) = ^(NSString * passphrase) {
        if (passphrase) {
            [[UserProfile sharedProfile] exportCredentialsWithPassphrase: passphrase];
            [HXOUI showErrorAlertWithMessageAsync: nil withTitle: @"credentials_exported_alert"];
            [self updateCurrentItems];
        }
    };

    [HXOUI enterStringAlert:nil withTitle: NSLocalizedString(@"credentials_file_choose_passphrase_alert",nil)
                  withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                     onCompletion: completion];
}

#pragma mark - Transfer Credentials

- (DatasheetItem*) transferCredentialsItem {
    if ( ! _transferCredentialsItem) {
        _transferCredentialsItem = [self itemWithIdentifier: @"credentials_transfer_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _transferCredentialsItem.visibilityMask = DatasheetModeEdit;
        _transferCredentialsItem.target = self;
        _transferCredentialsItem.action = @selector(transferCredentialsPressed:);
    }
    return _transferCredentialsItem;
}

- (void) transferCredentialsPressed: (id) sender {
    
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            if (![[UserProfile sharedProfile] transferCredentials]) {
                [AppDelegate.instance showOperationFailedAlert:NSLocalizedString(@"credentials_transfer_failed_no_xox_message",nil)
                                                     withTitle:NSLocalizedString(@"credentials_transfer_failed_no_xox_title",nil)
                                                   withOKBlock:^{
                                                       [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"credentials_transfer_install_app_url",nil)]];
                                                   }];
            }
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_transfer_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"transfer", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}


#pragma mark - Fetch Credentials

- (DatasheetItem*) fetchCredentialsItem {
    if ( ! _fetchCredentialsItem) {
        _fetchCredentialsItem = [self itemWithIdentifier: @"credentials_fetch_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _fetchCredentialsItem.visibilityMask = DatasheetModeEdit;
        _fetchCredentialsItem.dependencyPaths = @[@"foundCredentialsProviderApp"];
        _fetchCredentialsItem.target = self;
        _fetchCredentialsItem.action = @selector(fetchCredentialsPressed:);

    }
    return _fetchCredentialsItem;
}

- (void) fetchCredentialsPressed: (UIViewController*) sender {

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            NSURL * myFetchURL = [UserProfile sharedProfile].fetchCredentialsURL;
            if ([[UIApplication sharedApplication] openURL:myFetchURL]) {
                NSLog(@"Credentials openURL returned true");
            } else {
                NSLog(@"Credentials openURL returned false");
            }
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_fetch_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"credentials_fetch_confirm_btn_title", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - Import Credentials

- (DatasheetItem*) importCredentialsItem {
    if ( ! _importCredentialsItem) {
        _importCredentialsItem = [self itemWithIdentifier: @"credentials_import_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _importCredentialsItem.visibilityMask = DatasheetModeEdit;
        _importCredentialsItem.dependencyPaths = @[@"foundCredentialsFile"];
        _importCredentialsItem.target = self;
        _importCredentialsItem.action = @selector(importCredentialsPressed:);
        
    }
    return _importCredentialsItem;
}

- (void) importCredentialsPressed: (UIViewController*) sender {
    HXOStringEntryCompletion passphraseCompletion = ^(NSString *passphrase) {
        if (passphrase != nil) {
#define DEBUG_PRINT_CREDENTIALS_NOT
#ifdef DEBUG_PRINT_CREDENTIALS
            int result = [[UserProfile sharedProfile] readAndShowCredentialsWithPassphrase:passphrase withForce:NO];
#else
            int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:passphrase withForce:NO];
#endif
            switch (result) {
                case 1:
                    [[UserProfile sharedProfile] verfierChangePlease];
                    [AppDelegate.instance showFatalErrorAlertWithMessage: NSLocalizedString(@"credentials_imported_message",nil)
                                                               withTitle:NSLocalizedString(@"credentials_imported_title",nil)
                     ];
                    break;
                case -1:
                    [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_decryption_failed_message" withTitle:@"credentials_file_import_failed_title"];
                    break;
                case 0:
                    [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_equals_current_message" withTitle:@"credentials_file_equals_current_title"];
                    break;
                case -2:
                    [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_old_message" withTitle:@"credentials_receive_old_title"];
                    break;
                default:
                    NSLog(@"importCredentialsPressed: unhandled result %d", result);
                    break;
            }
        }
    };
    
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [HXOUI enterStringAlert:nil withTitle:NSLocalizedString(@"credentials_file_enter_passphrase_alert",nil) withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                       onCompletion: passphraseCompletion];
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_import_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"credentials_key_import_confirm_btn_title", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - Delete Account

- (DatasheetItem*) deleteAccountItem {
    if ( ! _deleteAccountItem) {
        _deleteAccountItem = [self itemWithIdentifier: @"account_delete_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _deleteAccountItem.visibilityMask = DatasheetModeEdit;
        _deleteAccountItem.target = self;
        _deleteAccountItem.action = @selector(deleteAccountPressed:);
        _deleteAccountItem.titleTextColor = [HXOUI theme].destructiveTextColor;
    }
    return _deleteAccountItem;
}

- (DatasheetSection*) destructiveSection {
    if ( ! _destructiveSection) {
        _destructiveSection = [DatasheetSection datasheetSectionWithIdentifier: @"destructive_section"];
        
        _destructiveSection.items = @[self.destructiveButton, self.deleteAccountItem];
    }
    return _destructiveSection;
}

- (void) deleteAccountPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [HXOBackend.instance  deleteAccountForReason:@"user request" handler:^(BOOL ok) {
                if (ok) {
                    /*
                    [AppDelegate.instance showGenericAlertWithTitle:@"account_delete_success_title" andMessage:@"account_delete_success_message" withOKBlock:nil];
                     */
                    [UserProfile sharedProfile].accountJustDeleted = YES;
                    [self updateCurrentItems];
                } else {
                    [AppDelegate.instance showGenericAlertWithTitle:@"account_delete_failed_title" andMessage:@"account_delete_failed_message" withOKBlock:nil];
                }
            }];
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"account_delete_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}


#pragma mark - Delete Credentials

- (void) deleteCredentialsPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[UserProfile sharedProfile] deleteCredentials];
            [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: NSLocalizedString(@"credentials_deleted_message", nil) withTitle:NSLocalizedString(@"credentials_deleted_title",nil)];

        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_delete_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - Delete Credentials File

- (DatasheetItem*) deleteCredentialsFileItem {
    if ( ! _deleteCredentialsFileItem) {
        _deleteCredentialsFileItem = [self itemWithIdentifier: @"credentials_file_delete_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _deleteCredentialsFileItem.visibilityMask = DatasheetModeEdit;
        _deleteCredentialsFileItem.target = self;
        _deleteCredentialsFileItem.action = @selector(deleteCredentialsFilePressed:);
    }
    return _deleteCredentialsFileItem;
}

- (void) deleteCredentialsFilePressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            if ([[UserProfile sharedProfile] deleteCredentialsFile]) {
                [HXOUI showErrorAlertWithMessageAsync: nil withTitle:@"credentials_file_deleted_alert"];
            }
            // TODO: show error message if it has not been deleted
            [self updateCurrentItems];
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_file_delete_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([segue.identifier isEqualToString: @"ShowContacts"]) {
        ContactListViewController * contactList = (ContactListViewController*)segue.destinationViewController;
        if ([item isEqual: self.contactCountItem]) {
            contactList.groupContactsToggle.selectedSegmentIndex = 0;
        } else if ([item isEqual: self.groupCountItem]) {
            contactList.groupContactsToggle.selectedSegmentIndex = 1;
        } else {
            NSLog(@"Kaputt: Unhandled segue item");
        }
#if HOCCER_UNIHELD
    } else if ([segue.identifier isEqualToString: @"showStudentId"]) {
        StudentIdViewController * vc = segue.destinationViewController;
        vc.image = [self studentIdImage];
#endif
    } else {
        [super prepareForSegue: segue withItem: item sender: sender];
    }
}

@end
