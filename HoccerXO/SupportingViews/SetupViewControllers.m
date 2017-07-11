//
//  SetupViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SetupViewControllers.h"

#import "DatasheetViewController.h"
#import "ProfileSheetController.h"
#import "UserProfile.h"
#import "HXOUI.h"
#import "HXOLocalization.h"
#import "AppDelegate.h"
#import "Environment.h"
#import "HXOUserDefaults.h"
#import "AppDelegate.h"

@interface SetupViewController ()
@end


@interface CredentialsSheet : DatasheetController

@property (nonatomic, strong) DatasheetSection * section;
@property (nonatomic, strong) DatasheetItem    * optionKeep;
@property (nonatomic, strong) DatasheetItem    * optionImport;
@property (nonatomic, strong) DatasheetItem    * optionRestore;
@property (nonatomic, strong) DatasheetItem    * optionCreateNew;
@property (nonatomic, strong) DatasheetItem    * optionFetch;
@property (nonatomic, strong) DatasheetItem    * optionFetchAll;

@property (nonatomic, strong) DatasheetItem    * selectedItem;

@end

@interface ProfileSetupSheet : ProfileSheetController

@property (nonatomic,assign) BOOL performRegistration;

@end

@implementation SetupViewController

- (void) viewDidLoad {
    BOOL showEula = [(AppDelegate*)[UIApplication sharedApplication].delegate needsEulaAcceptance];

    // Note(@agnat): This is utterly broken. somethingWithCredentials is always true.
    BOOL somethingWithCredentials = [UserProfile sharedProfile].isRegistered || [UserProfile sharedProfile].foundCredentialsFile || [UserProfile sharedProfile].foundCredentialsBackup || (![UserProfile sharedProfile].isRegistered && [UserProfile sharedProfile].foundCredentialsProviderApp);

    NSLog(@"reg = %d, credf= %d, backup= %d, provider=%d", [UserProfile sharedProfile].isRegistered,[UserProfile sharedProfile].foundCredentialsFile,[UserProfile sharedProfile].foundCredentialsBackup, [UserProfile sharedProfile].foundCredentialsProviderApp);

    //somethingWithCredentials = NO;

    if (showEula) {
        EulaViewController* vc = [self.storyboard instantiateViewControllerWithIdentifier: @"accept_eula"];
        vc.nextSegue = somethingWithCredentials ? @"cleanup_credentials" : @"setup_profile";
        vc.accept = YES;
        [self setViewControllers: @[vc]];
    } else if (somethingWithCredentials) {
        DatasheetViewController * vc = [self.storyboard instantiateViewControllerWithIdentifier: @"cleanup_credentials"];
        [self setViewControllers: @[vc]];
    } else {
        ((DatasheetViewController*)self.viewControllers[0]).inspectedObject = [UserProfile sharedProfile];
    }
}

@end

@implementation CredentialsSheet

- (void) commonInit {
    [super commonInit];

    self.title = NSLocalizedString(@"credentials_setup_nav_title", nil);

    NSMutableArray * texts = [NSMutableArray array];

    if ([UserProfile sharedProfile].foundCredentialsProviderApp) {
        [texts addObject: NSLocalizedString(@"credentials_setup_found_credentials_provider_text", nil)];
    }
 
    if ([UserProfile sharedProfile].foundCredentialsBackup) {
        [texts addObject: NSLocalizedString(@"credentials_setup_found_backup_text", nil)];
    }
    
    if ([UserProfile sharedProfile].isRegistered) {
        [texts addObject: HXOLocalizedString(@"credentials_setup_found_old_text", nil, HXOAppName())];
    }
    
    if ([UserProfile sharedProfile].foundCredentialsFile) {
        [texts addObject: NSLocalizedString(@"credentials_setup_found_file_text", nil)];
    }
    
    
    [texts addObject: NSLocalizedString(@"credentials_setup_question", nil)];


    //[texts addObject: NSLocalizedString(@"credentials_setup_create_account_text", nil)];

    self.section = [DatasheetSection datasheetSectionWithIdentifier: @"question"];
    self.section.title = [[NSAttributedString alloc] initWithString: [texts componentsJoinedByString: @"\n\n"] attributes: nil];
    self.section.titleTextAlignment = NSTextAlignmentLeft;

    self.optionKeep      = [self itemWithIdentifier: @"credentials_setup_keep_btn_title"   cellIdentifier: @"DatasheetActionCell"];
    self.optionImport    = [self itemWithIdentifier: @"credentials_setup_import_btn_title" cellIdentifier: @"DatasheetActionCell"];
    self.optionRestore    = [self itemWithIdentifier: @"credentials_setup_restore_btn_title" cellIdentifier: @"DatasheetActionCell"];
    self.optionCreateNew = [self itemWithIdentifier: @"credentials_setup_create_btn_title" cellIdentifier: @"DatasheetActionCell"];
    self.optionFetch    = [self itemWithIdentifier: @"credentials_setup_fetch_btn_title" cellIdentifier: @"DatasheetActionCell"];
    self.optionFetchAll    = [self itemWithIdentifier: @"credentials_setup_fetchall_btn_title" cellIdentifier: @"DatasheetActionCell"];

    self.optionKeep.accessoryStyle      =
    //self.optionImport.accessoryStyle    =
    self.optionCreateNew.accessoryStyle = DatasheetAccessoryDisclosure;

    self.optionKeep.target      =
    self.optionImport.target    =
    self.optionRestore.target   =
    self.optionFetchAll.target  =
    self.optionFetch.target     =
    self.optionCreateNew.target = self;

    self.optionKeep.action      =
    self.optionImport.action    =
    self.optionRestore.action   =
    self.optionFetchAll.action  =
    self.optionFetch.action     =
    self.optionCreateNew.action = @selector(buttonPressed:);

    [self.section setItems: @[self.optionFetchAll, self.optionFetch, self.optionImport, self.optionRestore, self.optionKeep, self.optionCreateNew]];
}

- (NSArray*) buildSections {
    return @[self.section];
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.optionKeep]) {
        return [UserProfile sharedProfile].isRegistered;
    } else if ([item isEqual: self.optionImport]) {
        return [UserProfile sharedProfile].foundCredentialsFile;
    } else if ([item isEqual: self.optionRestore]) {
        return [UserProfile sharedProfile].foundCredentialsBackup;
    } else if ([item isEqual: self.optionFetchAll]) {
        return [UserProfile sharedProfile].foundCredentialsProviderApp;
    } else if ([item isEqual: self.optionFetch]) {
        return [UserProfile sharedProfile].foundCredentialsProviderApp;
    }
    return [super isItemVisible: item];
}

- (void) buttonPressed: (id) sender {
    self.selectedItem = sender;
    if ([sender isEqual: self.optionImport]) {
        HXOStringEntryCompletion passphraseCompletion = ^(NSString *passphrase) {
            if (passphrase != nil) {
                int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:passphrase withForce:NO];
                switch (result) {
                    case CREDENTIALS_IMPORTED:
                        [[UserProfile sharedProfile] verfierChangePlease];
                        [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
                        break;
                    case CREDENTIALS_BROKEN:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_decryption_failed_message" withTitle:@"credentials_file_import_failed_title"];
                        break;
                    case CREDENTIALS_IDENTICAL:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_equals_current_message" withTitle:@"credentials_file_equals_current_title"];
                        [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
                        break;
                    case CREDENTIALS_OLDER:
                        [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_old_message" withTitle:@"credentials_receive_old_title"];
                        break;
                    default:
                        NSLog(@"importCredentialsPressed: unhandled result %d", result);
                        break;
                }
            }
        };

        [HXOUI enterStringAlert: nil
                      withTitle: NSLocalizedString(@"credentials_file_enter_passphrase_alert",nil)
                withPlaceHolder: NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                   onCompletion: passphraseCompletion];

    } else  if ([sender isEqual: self.optionRestore]) {
        int result = [[UserProfile sharedProfile] restoreCredentialsWithForce:NO];
        switch (result) {
            case CREDENTIALS_IMPORTED:
                [[UserProfile sharedProfile] verfierChangePlease];
                [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
                break;
            case CREDENTIALS_BROKEN:
                [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_decryption_failed_message" withTitle:@"credentials_file_import_failed_title"];
                break;
            case CREDENTIALS_IDENTICAL:
                [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_equals_current_message" withTitle:@"credentials_file_equals_current_title"];
                [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
                break;
            case CREDENTIALS_OLDER:
                [HXOUI showErrorAlertWithMessageAsync:@"credentials_receive_old_message" withTitle:@"credentials_receive_old_title"];
                break;
            default:
                NSLog(@"importCredentialsPressed: unhandled result %d", result);
                break;
        }
        
    } else  if ([sender isEqual: self.optionFetchAll]) {
        // TODO: refactor, this block is a copy of code from ProfileSheetController.m
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
    } else  if ([sender isEqual: self.optionFetch]) {
        // TODO: refactor, this block is a copy of code from ProfileSheetController.m
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
    } else {
        [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([segue.identifier isEqualToString: @"showProfileSetup"]) {
        DatasheetViewController * vc = segue.destinationViewController;
        ((ProfileSetupSheet*)vc.dataSheetController).performRegistration = [item isEqual: self.optionCreateNew];
        vc.inspectedObject = [UserProfile sharedProfile];
    }
}


@end

@implementation ProfileSetupSheet

- (void) inspectedObjectDidChange {
    if ( ! self.isEditing) {
        [self editModeChanged: nil];
    }
    // doesn't look good on 3.5" displays
    // [self.delegate makeFirstResponder: [self indexPathForItem: self.nicknameItem]];
    [super inspectedObjectDidChange];
}

- (BOOL) isCancelable {
    return NO;
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    NSArray * hidden = @[self.keyItem, self.exportCredentialsItem, self.importCredentialsItem, self.deleteCredentialsFileItem, self.transferCredentialsItem, self.fetchCredentialsItem, self.fetchArchiveItem, self.archiveAllItem, self.archiveImportItem, self.transferArchiveItem, self.destructiveButton];
    if ([hidden indexOfObject: item] != NSNotFound) {
        return NO;
    }
    return [super isItemVisible: item];
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];
    [((AppDelegate *)[[UIApplication sharedApplication] delegate]) setupDone: self.performRegistration  || ![UserProfile sharedProfile].isRegistered];
    [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
    [((UIViewController*)self.delegate).navigationController dismissViewControllerAnimated: YES completion: nil];
}

@end

@implementation EulaViewController

- (void) viewDidLoad {
    NSURL * eulaURL = [(AppDelegate*)[UIApplication sharedApplication].delegate eulaURL];

    NSError * error = nil;
    self.textView.attributedText = [[NSAttributedString alloc] initWithURL: eulaURL
                                                                   options: @{}
                                                        documentAttributes: nil
                                                                     error: &error];

    //self.acceptButton.title = NSLocalizedString(@"eula_accept_button_title", nil);
    //self.declineButton.title = NSLocalizedString(@"eula_decline_button_title", nil);
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    if (self.accept) {
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"eula_decline_button_title", nil)
                                         style: UIBarButtonItemStylePlain
                                        target: self
                                        action:@selector(decline:)];
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"eula_accept_button_title", nil)
                                             style: UIBarButtonItemStylePlain
                                            target: self
                                            action:@selector(accept:)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (IBAction) accept: (id) sender {
    NSString * acceptedVersion = [(AppDelegate*)[UIApplication sharedApplication].delegate eulaVersion];
    [[NSUserDefaults standardUserDefaults] setValue: acceptedVersion forKey: @"AcceptedEulaVersion"];
    [self performSegueWithIdentifier: self.nextSegue sender: self];
}

- (IBAction) decline: (id) sender {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"eula_declined_title", nil)
                                                     message: HXOLocalizedString(@"eula_declined_message", nil, HXOAppName(), nil)
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 exit(0);
                                             }
                                           cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                           otherButtonTitles: nil];
    [alert show];
}

@end

