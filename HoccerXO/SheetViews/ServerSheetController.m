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
    self.inspectedObject = [AppDelegate instance];
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
        NSLog(@"server: %@", item.currentValue);
    }
}

- (DatasheetSection*) serverSection {
    if ( ! _serverSection) {
        _serverSection = [DatasheetSection datasheetSectionWithIdentifier: @"server_section"];
        _serverSection.items = @[self.serverSwitch, self.passwordItem];
    }
    return _serverSection;
}

- (DatasheetItem*) passwordItem {
    if ( ! _passwordItem) {
        _passwordItem = [self itemWithIdentifier: @"server_password_title" cellIdentifier: @"DatasheetTextInputCell"];
        _passwordItem.valuePath = @"httpServerPassword";
        _passwordItem.valuePlaceholder = NSLocalizedString(@"server_password_placeholder", nil);
        _passwordItem.returnKeyType = UIReturnKeyDone;
    }
    return _passwordItem;
}

- (DatasheetItem*) serverSwitch {
    if ( ! _serverSwitch) {
        _serverSwitch = [self itemWithIdentifier: @"server_nav_title" cellIdentifier: @"DatasheetSwitchCell"];
        _serverSwitch.valuePath = @"httpServer.isRunning";
    }
    return _serverSwitch;
}


@end
