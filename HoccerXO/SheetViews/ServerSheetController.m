//
//  ServerSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 27.01.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "ServerSheetController.h"

#import "AppDelegate.h"
#import "HXOLocalization.h"
#import "HXOUserDefaults.h"
#import "HTTPServerController.h"
#import "tab_settings.h"

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

    // Note(@agnat): See below...
    [super setInspectedObject: [AppDelegate instance].httpServer];
}


- (void) setInspectedObject:(id)inspectedObject {
    // Note(@agnat): Workaround for pavels workaround. The DatasheetViewController
    // currently clears the inspected object when the view disappears. This kind
    // of fucks us here. As a workaround we overload setInspectedObject to do
    // nothing and call [super setInspectedObject: ...] above.
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: self.inspectedObject] && [keyPath isEqualToString: @"canRun"]) {
        [self forceFooterTextRefresh];
        [self updateCurrentItems];
    }
}

- (NSString*) title {
    return HXOLabelledLocalizedString(@"server_nav_title", nil);
}

- (VectorArt*) tabBarIcon {
    return [[tab_settings alloc] init];
}

- (NSArray*) buildSections {
    return @[self.serverSection];
}

- (BOOL) isCancelable { return NO; }

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.addressItem]) {
        return self.server.canRun && self.server.isRunning;
    }
    return [super isItemVisible: item];
}

- (void) didChangeCurrentValueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.passwordItem]) {
        [[HXOUserDefaults standardUserDefaults] setValue: item.currentValue forKey:kHXOHttpServerPassword];
        [[HXOUserDefaults standardUserDefaults] synchronize];
    } else if ([item isEqual: self.serverSwitch]) {
        [self toggleHTTPServer: [item.currentValue boolValue]];
        [item clearCurrentValue];
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
    [self updateCurrentItems];
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

- (id) valueForItem:(DatasheetItem *)item {
    if ([item isEqual: self.serverSwitch]) {
        return @(self.server.canRun && self.server.isRunning);
    }
    return [super valueForItem: item];
}


- (NSAttributedString*) footerTextForSection: (DatasheetSection*) section {
    if ([section.identifier isEqualToString: self.serverSection.identifier]) {
        BOOL running = self.server.isRunning;
        BOOL can_run = self.server.canRun;

        NSString * boxName = HXOLabelledLocalizedString(@"server_nav_title", nil);
        NSString * appName = HXOAppName();

        NSString * text = HXOLocalizedString(running ? @"server_running" : can_run ? @"server_stopped_can_run" : @"server_stopped_can_not_run", nil, boxName, appName);
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
        _passwordItem.returnKeyType = UIReturnKeyDone;
    }
    return _passwordItem;
}

- (DatasheetItem*) serverSwitch {
    if ( ! _serverSwitch) {
        _serverSwitch = [self itemWithIdentifier: @"server_nav_title" cellIdentifier: @"DatasheetSwitchCell"];
        _serverSwitch.dependencyPaths = @[@"canRun", @"isRunning"];
    }
    return _serverSwitch;
}

- (DatasheetItem*) addressItem {
    if ( ! _addressItem) {
        _addressItem = [self itemWithIdentifier: @"server_address_title" cellIdentifier: @"DatasheetKeyValueCell"];
        _addressItem.valuePath = @"url";
        _addressItem.adjustFontSize = YES;
        _addressItem.dependencyPaths = @[@"isRunning", @"canRun"];
    }
    return _addressItem;
}

@end
