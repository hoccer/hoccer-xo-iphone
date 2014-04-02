//
//  ContactSheet.m
//  HoccerXO
//
//  Created by David Siegel on 31.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetController.h"

#import "Contact.h"
#import "ChatViewController.h"
#import "HXOUserDefaults.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "ProfileAvatarView.h"
#import "HXOUI.h"

static const BOOL RELATIONSHIP_DEBUG = NO;

@interface ContactSheetController ()

@property (nonatomic,readonly) DatasheetItem * chatItem;
@property (nonatomic,readonly) DatasheetItem * blockContactItem;
@property (nonatomic,readonly) Contact       * contact;

@property (nonatomic,readonly) HXOBackend    * chatBackend;
@property (nonatomic,readonly) AppDelegate   * appDelegate;

@end

@implementation ContactSheetController

@synthesize chatItem = _chatItem;
@synthesize blockContactItem = _blockContactItem;
@synthesize chatBackend = _chatBackend;

- (void) commonInit {
    [super commonInit];

    self.avatarItem.dependencyPaths = @[@"relationshipState"];

    self.nicknameItem.enabledMask = DatasheetModeNone;

    self.keyItem.visibilityMask = DatasheetModeView;
    self.keyItem.dependencyPaths = @[@"verifiedKey"];

    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.title = @"delete_contact";
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(deleteContactPressed:);

    self.destructiveSection.items = [@[self.blockContactItem] arrayByAddingObjectsFromArray: self.destructiveSection.items];

    self.isEditable = YES;
}

- (Contact*) contact {
    if ([self.inspectedObject isKindOfClass: [Contact class]]) {
        return self.inspectedObject;
    }
    return nil;
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.chatItem, self.keyItem];
    return section;
}

- (DatasheetItem*) chatItem {
    if ( ! _chatItem) {
        _chatItem = [self itemWithIdentifier: @"chat_with_contact" cellIdentifier: @"DatasheetKeyValueCell"];
        _chatItem.dependencyPaths = @[@"messages.@count"];
        _chatItem.segueIdentifier = @"showChat";
        _chatItem.visibilityMask = DatasheetModeView;
        _chatItem.accessoryStyle = DatasheetAccessoryDisclosure;
    }
    return _chatItem;
}

- (DatasheetItem*) blockContactItem {
    if ( ! _blockContactItem) {
        _blockContactItem = [self itemWithIdentifier: @"block_contact" cellIdentifier: @"DatasheetActionCell"];
        _blockContactItem.dependencyPaths = @[@"relationshipState", kHXONickName];
        _blockContactItem.visibilityMask = DatasheetModeEdit;
        _blockContactItem.target = self;
        _blockContactItem.action = @selector(blockToggled:);
    }
    return _blockContactItem;
}

- (id) valueForItem: (DatasheetItem*) item {
    if ([item isEqual: self.chatItem]) {
        return @(self.contact.messages.count);
    } else if ([item isEqual: self.keyItem]) {
        return [self keyItemTitle];
    }
    return [super valueForItem: item];
}

- (NSString*) titleForItem:(DatasheetItem *)item {
    if ([item isEqual: self.blockContactItem]) {
        return [self blockItemTitle];
    }
    return nil;
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.chatItem]) {
        return self.contact.messages.count > 0 && [super isItemVisible: item];
    } else if ([item isEqual: self.blockContactItem]) {
        NSString * state = self.contact.relationshipState;
        return ([state isEqualToString: @"blocked"] || [state isEqualToString: @"friend"]) && [super isItemVisible:item];
    }
    return [super isItemVisible: item];
}

- (NSString*) valueFormatStringForItem:(DatasheetItem *)item {
    if ([item isEqual: self.chatItem]) {
        return self.contact.messages.count == 1 ? @"message_count_format_singular" : @"message_count_format_plural";
    }
    return nil;
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
    [super didChangeValueForItem: item];
    if ([item isEqual: self.avatarItem]) {
        self.avatarView.isBlocked = [self.contact.relationshipState isEqualToString: @"blocked"];
    }

}


- (NSString*) keyItemTitle {
    NSString * titleKey;
    if (self.contact.verifiedKey == nil) {
        titleKey = @"unverified_key_title";
    } else if ([self.contact.verifiedKey isEqualToData:self.contact.publicKey]) {
        titleKey = @"verified_key_title";
    } else {
        titleKey = @"untrusted_key_title";
    }
    return NSLocalizedString(titleKey, nil);
}


#pragma mark - UI Actions

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    if ([item isEqual: self.chatItem]) {
        ChatViewController * chatView = segue.destinationViewController;
        chatView.inspectedObject = self.contact;
    } else  {
        [super prepareForSegue: segue withItem: item sender: sender];
    }
}


#pragma mark - Block Contact


- (NSString*) blockItemTitle {
    NSString * state = self.contact.relationshipState;
    NSString * formatKey = nil;
    if ([state isEqualToString: @"friend"]) {
        formatKey = @"contact_block";
    } else if ([state isEqualToString: @"blocked"]) {
        formatKey = @"contact_unblock";
    }
    return formatKey ? [NSString stringWithFormat: NSLocalizedString(formatKey, nil), self.nicknameItem.currentValue] : nil;
}

- (void) blockToggled: (id) sender {
    if ([self.contact.relationshipState isEqualToString: @"friend"]) {
        // NSLog(@"friend -> blocked");
        [self.chatBackend blockClient: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"blockClient: %@", success ? @"success" : @"failed");
        }];
    } else if ([self.contact.relationshipState isEqualToString: @"blocked"]) {
        // NSLog(@"blocked -> friend");
        [self.chatBackend unblockClient: self.contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"unblockClient: %@", success ? @"success" : @"failed");
        }];
    } else {
        NSLog(@"ContactSheetController toggleBlockedPressed: unhandled status %@", self.contact.status);
    }
}

#pragma mark - Delete Contact

- (void) deleteContactPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock handleAnswer = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [self deleteContact: self.contact];
        }
    };
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"delete_contact_safety_question", nil)
                                                 completionBlock: handleAnswer
                                               cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                          destructiveButtonTitle: NSLocalizedString(@"delete_contact_confirm", nil)
                                               otherButtonTitles: nil];
    [sheet showInView: sender.view];
}

- (void) deleteContact: (Contact*) contact {
    //[self.delegate controllerDidFinish: self];
    NSLog(@"deleting contact with relationshipState %@", contact.relationshipState);
    if ([contact.relationshipState isEqualToString:@"groupfriend"] || [contact.relationshipState isEqualToString:@"kept"]) {
        [self.chatBackend handleDeletionOfContact:contact];
    } else {
        [self.chatBackend depairClient: contact.clientId handler:^(BOOL success) {
            if (RELATIONSHIP_DEBUG || !success) NSLog(@"depair client: %@", success ? @"succcess" : @"failed");
        }];
    }
    [self.delegate controllerDidFinish: self];
}

#pragma mark - Attic

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
