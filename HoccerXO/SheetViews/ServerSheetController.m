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

@property (nonatomic,readonly) HTTPServerController * server;

@property (nonatomic, readonly) DatasheetSection    * serverSection;
@property (nonatomic, readonly) DatasheetItem       * serverSwitch;
@property (nonatomic, readonly) DatasheetItem       * passwordItem;
@property (nonatomic, readonly) DatasheetItem       * addressItem;

@end

@implementation ServerSheetController

@synthesize serverSection = _serverSection;
@synthesize serverSwitch  = _serverSwitch;
@synthesize passwordItem  = _passwordItem;
@synthesize addressItem   = _addressItem;

- (HTTPServerController*) server {
    return self.inspectedObject;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.inspectedObject = [AppDelegate instance].httpServer;
}

- (void) setInspectedObject:(id)inspectedObject {
    if (self.inspectedObject) {
        [self.inspectedObject removeObserver: self forKeyPath: @"canRun"];
    }
    [super setInspectedObject: inspectedObject];
    if (self.inspectedObject) {
        [self.inspectedObject addObserver: self forKeyPath: @"canRun" options: NSKeyValueObservingOptionNew context: NULL];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: self.inspectedObject] && [keyPath isEqualToString: @"canRun"]) {
        if (self.server.isRunning && ! self.server.canRun) {
            [self toggleHTTPServer: NO];
        }
        [self forceFooterTextRefresh];
    }
}

- (NSString*) title {
    return NSLocalizedString(@"server_nav_title", nil);
}

- (NSArray*) buildSections {
    return @[self.serverSection];
}

- (BOOL) isCancelable { return NO; }

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.addressItem]) {
        return self.server.isRunning;
    }
    return [super isItemVisible: item];
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
    if (start) {
        if (self.server.canRun && ! self.server.isRunning) {
            NSLog(@"starting server");
            [self.server start];
        }
    } else {
        if (self.server.isRunning) {
            NSLog(@"stopping server");
            [self.server stop];
        }
    }
    [self forceFooterTextRefresh];
}

- (void) forceFooterTextRefresh {
    // Note(@agnat): Force an update of the table to update the footer text.
    // There probably is a more elegant way to get this right...
    [[(id)self.delegate tableView] reloadData];
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    if ([item isEqual: self.serverSwitch]) {
        return self.server.canRun;
    }
    return [super isItemEnabled: item];
}

- (NSAttributedString*) footerTextForSection: (DatasheetSection*) section {
    if ([section.identifier isEqualToString: self.serverSection.identifier]) {
        BOOL running = self.server.isRunning;
        BOOL can_run = self.server.canRun;
        NSString * text = NSLocalizedString(running ? @"server_running" : can_run ? @"server_stopped_can_run" : @"server_stopped_can_not_run", nil);
        return [[NSAttributedString alloc] initWithString: text];
    }
    return nil;
}

- (DatasheetSection*) serverSection {
    if ( ! _serverSection) {
        _serverSection = [DatasheetSection datasheetSectionWithIdentifier: @"server_section"];
        _serverSection.items = @[self.serverSwitch, self.passwordItem, self.addressItem];
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

- (DatasheetItem*) serverSwitch {
    if ( ! _serverSwitch) {
        _serverSwitch = [self itemWithIdentifier: @"server_nav_title" cellIdentifier: @"DatasheetSwitchCell"];
        _serverSwitch.valuePath = @"isRunning";
        _serverSwitch.dependencyPaths = @[@"canRun"];
    }
    return _serverSwitch;
}

- (DatasheetItem*) addressItem {
    if ( ! _addressItem) {
        _addressItem = [self itemWithIdentifier: @"server_address_title" cellIdentifier: @"DatasheetKeyValueCell"];
        _addressItem.valuePath = @"url";
        _addressItem.adjustFontSize = YES;
    }
    return _addressItem;
}


@end
