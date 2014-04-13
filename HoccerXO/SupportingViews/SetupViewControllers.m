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
#import "AppDelegate.h"
#import "Environment.h"
#import "HXOUserDefaults.h"

@interface SetupViewController ()
@end


@interface CredentialsSheet : DatasheetController

@property (nonatomic, strong) DatasheetSection * section;
@property (nonatomic, strong) DatasheetItem    * optionKeep;
@property (nonatomic, strong) DatasheetItem    * optionImport;
@property (nonatomic, strong) DatasheetItem    * optionCreateNew;

@property (nonatomic, strong) DatasheetItem    * selectedItem;

@end

@interface ProfileSetupSheet : ProfileSheetController

@property (nonatomic, assign) BOOL performRegistration;

@end

@implementation SetupViewController

- (void) viewDidLoad {
    BOOL somethingWithCredentials = [UserProfile sharedProfile].isRegistered || [UserProfile sharedProfile].foundCredentialsFile;

    if (somethingWithCredentials) {
        DatasheetViewController * vc = [self.storyboard instantiateViewControllerWithIdentifier: @"cleanup_credentials"];
        [self setViewControllers: @[vc]];
    }
}

@end

@implementation CredentialsSheet

- (void) commonInit {
    [super commonInit];

    self.title = NSLocalizedString(@"credentials_setup_nav_title", nil);

    NSMutableArray * texts = [NSMutableArray array];

    if ([UserProfile sharedProfile].isRegistered) {
        [texts addObject: NSLocalizedString(@"credentials_setup_found_old_text", nil)];
    }
    
    if ([UserProfile sharedProfile].foundCredentialsFile) {
        [texts addObject: NSLocalizedString(@"credentials_setup_found_file_text", nil)];
    }

    //[texts addObject: NSLocalizedString(@"credentials_setup_create_account_text", nil)];

    self.section = [DatasheetSection datasheetSectionWithIdentifier: @"question"];
    self.section.title = [[NSAttributedString alloc] initWithString: [texts componentsJoinedByString: @"\n\n"] attributes: nil];
    self.section.titleTextAlignment = NSTextAlignmentLeft;

    self.optionKeep      = [self itemWithIdentifier: @"credentials_setup_keep_btn_title"   cellIdentifier: @"DatasheetActionCell"];
    self.optionImport    = [self itemWithIdentifier: @"credentials_setup_import_btn_title" cellIdentifier: @"DatasheetActionCell"];
    self.optionCreateNew = [self itemWithIdentifier: @"credentials_setup_create_btn_title" cellIdentifier: @"DatasheetActionCell"];

    self.optionKeep.accessoryStyle      =
    //self.optionImport.accessoryStyle    =
    self.optionCreateNew.accessoryStyle = DatasheetAccessoryDisclosure;

    self.optionKeep.target      =
    self.optionImport.target    =
    self.optionCreateNew.target = self;

    self.optionKeep.action      =
    self.optionImport.action    =
    self.optionCreateNew.action = @selector(buttonPressed:);

    [self.section setItems: @[self.optionKeep, self.optionImport, self.optionCreateNew]];
}

- (NSArray*) buildSections {
    return @[self.section];
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.optionKeep]) {
        return [UserProfile sharedProfile].isRegistered;
    } else if ([item isEqual: self.optionImport]) {
        return [UserProfile sharedProfile].foundCredentialsFile;
    }
    return [super isItemVisible: item];
}

- (void) buttonPressed: (id) sender {
    self.selectedItem = sender;
    if ([sender isEqual: self.optionImport]) {
        HXOStringEntryCompletion passphraseCompletion = ^(NSString *passphrase) {
            if (passphrase != nil) {
                int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:passphrase];
                switch (result) {
                    case 1:
                        [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
                        break;
                    case -1:
                        [HXOUI showErrorAlertWithMessageAsync:@"Wrong decryption passphrase or credentials file damaged. Try again." withTitle:@"Credentials Import Failed"];
                        break;
                    case 0:
                        [HXOUI showErrorAlertWithMessageAsync:@"Imported credentials are the same as the active ones." withTitle:@"Same credentials"];
                        break;
                    default:
                        NSLog(@"importCredentialsPressed: unhandled result %d", result);
                        break;
                }
            }
        };

        [HXOUI enterStringAlert: nil
                      withTitle: NSLocalizedString(@"Enter decryption passphrase",nil)
                withPlaceHolder: NSLocalizedString(@"Enter passphrase",nil)
                   onCompletion: passphraseCompletion];

    } else {
        [(UIViewController*)self.delegate performSegueWithIdentifier: @"showProfileSetup" sender: self];
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([segue.identifier isEqualToString: @"showProfileSetup"]) {
        DatasheetViewController * vc = segue.destinationViewController;
        ((ProfileSetupSheet*)vc.dataSheetController).performRegistration = [self.selectedItem isEqual: self.optionCreateNew];
        vc.inspectedObject = [UserProfile sharedProfile];
    }
}

@end

@implementation ProfileSetupSheet

- (void) inspectedObjectDidChange {
    if ( ! self.isEditing) {
        [self editModeChanged: nil];
    }
    [self.delegate makeFirstResponder: [self indexPathForItem: self.nicknameItem]];
    [super inspectedObjectDidChange];
}

- (BOOL) isCancelable {
    return NO;
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    NSArray * hidden = @[self.keyItem, self.exportCredentialsItem, self.importCredentialsItem, self.deleteCredentialsFileItem, self.destructiveButton ];
    if ([hidden indexOfObject: item] != NSNotFound) {
        return NO;
    }
    return [super isItemVisible: item];
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];
    [((AppDelegate *)[[UIApplication sharedApplication] delegate]) setupDone: self.performRegistration];
    [[HXOUserDefaults standardUserDefaults] setBool: YES forKey: [[Environment sharedEnvironment] suffixedString:kHXOFirstRunDone]];
    [((UIViewController*)self.delegate).navigationController dismissViewControllerAnimated: YES completion: nil];
}

@end

