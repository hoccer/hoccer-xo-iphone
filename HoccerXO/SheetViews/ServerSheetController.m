//
//  ServerSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 27.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "ServerSheetController.h"

#import "AppDelegate.h"
#import "HXOUserDefaults.h"
#import "HTTPServerController.h"

@interface ServerSheetController ()

@property (nonatomic, readonly) DatasheetSection * serverSection;
@property (nonatomic, readonly) DatasheetItem    * serverSwitch;
@property (nonatomic, readonly) DatasheetItem    * passwordItem;

@end

@implementation ServerSheetController

@synthesize serverSection = _serverSection;
@synthesize serverSwitch  = _serverSwitch;
@synthesize passwordItem  = _passwordItem;

- (void) awakeFromNib {
    [super awakeFromNib];
    self.inspectedObject = [AppDelegate instance].httpServer;
}

- (NSString*) title {
    return NSLocalizedString(@"server_nav_title", nil);
}

- (NSArray*) buildSections {
    return @[self.serverSection];
}

- (void) didChangeCurrentValueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.passwordItem]) {
        [[HXOUserDefaults standardUserDefaults] setValue: item.currentValue forKey:kHXOHttpServerPassword];
        [[HXOUserDefaults standardUserDefaults] synchronize];
    } else if ([item isEqual: self.serverSwitch]) {
        [self toggleHTTPServer: [item.currentValue boolValue]];
    }
}

- (void) toggleHTTPServer: (BOOL) start {
    BOOL httpPossible = YES;
    if (start) {
        if (httpPossible) {
            NSLog(@"starting server");
            [(HTTPServerController*)self.inspectedObject start];
        }
    } else {
        NSLog(@"stopping server");
        [(HTTPServerController*)self.inspectedObject stop];
    }
    // Note(@agnat): Force an update of the table to update the footer text.
    // There probably is a more elegant way to get this right...
    [[(id)self.delegate tableView] reloadData];
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    if ([item isEqual: self.serverSwitch]) {
        return YES;
    }
    return [super isItemEnabled: item];
}

- (DatasheetSection*) serverSection {
    if ( ! _serverSection) {
        _serverSection = [DatasheetSection datasheetSectionWithIdentifier: @"server_section"];
        _serverSection.items = @[self.serverSwitch, self.passwordItem];
        _serverSection.delegate = self;
    }
    return _serverSection;
}

- (DatasheetItem*) passwordItem {
    if ( ! _passwordItem) {
        _passwordItem = [self itemWithIdentifier: @"server_password_title" cellIdentifier: @"DatasheetTextInputCell"];
        _passwordItem.valuePath = @"password";
        _passwordItem.valuePlaceholder = NSLocalizedString(@"server_password_placeholder", nil);
        _passwordItem.returnKeyType = UIReturnKeyDone;
    }
    return _passwordItem;
}

- (NSAttributedString*) footerTextForSection: (DatasheetSection*) section {
    if ([section.identifier isEqualToString: self.serverSection.identifier]) {
        BOOL running = [self.inspectedObject isRunning];
        return [[NSAttributedString alloc] initWithString: running ? @"Running" : @"Stopped"];
    }
    return nil;
}

- (DatasheetItem*) serverSwitch {
    if ( ! _serverSwitch) {
        _serverSwitch = [self itemWithIdentifier: @"server_nav_title" cellIdentifier: @"DatasheetSwitchCell"];
        _serverSwitch.valuePath = @"isRunning";
    }
    return _serverSwitch;
}


@end
