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

@interface ProfileSheetController ()

@property (nonatomic, readonly) UserProfile      * userProfile;

@property (nonatomic, readonly) DatasheetSection * credentialsSection;

@property (nonatomic, strong) ModalTaskHUD * hud;

@end

@implementation ProfileSheetController

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

- (UserProfile*) userProfile {
    return [self.inspectedObject isKindOfClass: [UserProfile class]] ? self.inspectedObject : nil;
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];

    [self.userProfile saveProfile];
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.keyItem];
    return section;
}

- (DatasheetSection*) credentialsSection {
    if ( ! _credentialsSection) {
        _credentialsSection = [DatasheetSection datasheetSectionWithIdentifier: @"credentials_section"];
        _credentialsSection.headerViewIdentifier = @"DatasheetFooterTextView";
        _credentialsSection.items = @[self.exportCredentialsItem,
                                      self.importCredentialsItem,
                                      self.deleteCredentialsFileItem
                                      
#ifndef HOCCER_CLASSIC
                                      , self.transferCredentialsItem
#else
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
    [sections addObject: self.credentialsSection];
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.importCredentialsItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    } else if ([item isEqual: self.deleteCredentialsFileItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    } else if ([item isEqual: self.fetchCredentialsItem]) {
        return self.userProfile.foundCredentialsProviderApp && [super isItemVisible: item];
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
                                 destructiveButtonTitle: NSLocalizedString(@"import", nil)
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
                    //[HXOUI showErrorAlertWithMessageAsync: @"archive_ok_alert_message" withTitle:@"archive_ok_alert_title"];
                    [self openWithInteractionController:url withUTI:kHXOTransferArchiveUTI withName:kHXODefaultArchiveName];
                }
            }];
            
        }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"archive_transfer_open_with_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"archive", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

- (void) openWithInteractionController:(NSURL *)myURL withUTI:(NSString*)uti withName:(NSString*)name {
    NSLog(@"openWithInteractionController");

    NSLog(@"openWithInteractionController: uti=%@, name = %@, url = %@", uti, name, myURL);
    self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
    self.interactionController.delegate = self;
    self.interactionController.UTI = uti;
    self.interactionController.name = name;
    [self.interactionController presentOpenInMenuFromRect:CGRectNull inView:self.delegate.view animated:YES];
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller {
    return self.delegate;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller
{
    return self.delegate.view;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller {
    return self.delegate.view.frame;
}
- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    NSLog(@"willBeginSendingToApplication %@", application);
    self.hud = [ModalTaskHUD modalTaskHUDWithTitle: NSLocalizedString(@"archive_sending_hud_title", nil)];
    [self.hud show];
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    NSLog(@"didEndSendingToApplication %@", application);
    [self.hud dismiss];
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
            int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:passphrase];
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



#pragma mark - Delete Credentials

- (void) deleteCredentialsPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[UserProfile sharedProfile] deleteCredentials];
            [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: @"Your login credentials have been deleted. Hoccer XO will terminate now." withTitle:@"Login Credentials Deleted"];

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

@end
