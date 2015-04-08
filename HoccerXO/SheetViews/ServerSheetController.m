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
#import "TutorialViewController.h"

@interface ServerSheetController ()

@property (nonatomic,readonly) HTTPServerController * server;

@property (nonatomic, readonly) DatasheetSection    * serverSection;
@property (nonatomic, readonly) DatasheetItem       * serverSwitch;
@property (nonatomic, readonly) DatasheetItem       * passwordItem;
@property (nonatomic, readonly) DatasheetItem       * addressItem;

@property (nonatomic, readonly) DatasheetSection    * connectionTutorialSection;
@property (nonatomic, readonly) DatasheetItem       * webTutorial;
@property (nonatomic, readonly) DatasheetItem       * macTutorial;
@property (nonatomic, readonly) DatasheetItem       * winXpTutorial;
@property (nonatomic, readonly) DatasheetItem       * win7Tutorial;
@property (nonatomic, readonly) DatasheetItem       * win8Tutorial;

@end

@implementation ServerSheetController

@synthesize serverSection = _serverSection;
@synthesize serverSwitch  = _serverSwitch;
@synthesize passwordItem  = _passwordItem;
@synthesize addressItem   = _addressItem;
@synthesize connectionTutorialSection = _connectionTutorialSection;
@synthesize webTutorial = _webTutorial;
@synthesize macTutorial = _macTutorial;
@synthesize winXpTutorial = _winXpTutorial;
@synthesize win7Tutorial = _win7Tutorial;
@synthesize win8Tutorial = _win8Tutorial;

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
    return @[self.serverSection, self.connectionTutorialSection];
}

- (BOOL) isCancelable { return NO; }

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.webTutorial] || [item isEqual: self.addressItem] || [item isEqual: self.macTutorial] || [item isEqual: self.win7Tutorial] || [item isEqual: self.winXpTutorial] || [item isEqual: self.win8Tutorial]) {
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
        NSString * text;

        if (running) {
            text = @"";
        } else if (can_run) {
            text = HXOLocalizedString(@"server_stopped_can_run", nil, boxName, boxName, appName);
        } else {
            text = HXOLocalizedString(@"server_stopped_can_not_run", nil, boxName, appName);
        }

        return [[NSAttributedString alloc] initWithString: text];
    }
    return nil;
}

#pragma mark - Server Section

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

#pragma mark - Tutorial Section

- (DatasheetSection*) connectionTutorialSection {
    if ( ! _connectionTutorialSection) {
        _connectionTutorialSection = [DatasheetSection datasheetSectionWithIdentifier: @"server_tutorial_section"];
        _connectionTutorialSection.items = @[self.webTutorial/* self.macTutorial, self.win8Tutorial, self.win7Tutorial, self.winXpTutorial*/];
        _connectionTutorialSection.title = [[NSAttributedString alloc] initWithString: HXOLocalizedString(@"server_tutorial_section_title", nil) attributes: nil];
    }
    return _connectionTutorialSection;
}

- (DatasheetItem*) webTutorial {
    if ( ! _webTutorial) {
        _webTutorial = [self itemWithIdentifier: @"server_tutorial_title_web" cellIdentifier: @"DatasheetActionCell"];
        _webTutorial.accessoryStyle = DatasheetAccessoryDisclosure;
        _webTutorial.segueIdentifier = @"showTutorial";
    }
    return _webTutorial;
}

- (DatasheetItem*) macTutorial {
    if ( ! _macTutorial) {
        _macTutorial = [self itemWithIdentifier: @"server_tutorial_title_mac" cellIdentifier: @"DatasheetActionCell"];
        _macTutorial.accessoryStyle = DatasheetAccessoryDisclosure;
        _macTutorial.segueIdentifier = @"showTutorial";
    }
    return _macTutorial;
}

- (DatasheetItem*) win7Tutorial {
    if ( ! _win7Tutorial) {
        _win7Tutorial = [self itemWithIdentifier: @"server_tutorial_title_win7" cellIdentifier: @"DatasheetActionCell"];
        _win7Tutorial.accessoryStyle = DatasheetAccessoryDisclosure;
        _win7Tutorial.segueIdentifier = @"showTutorial";
    }
    return _win7Tutorial;
}

- (DatasheetItem*) win8Tutorial {
    if ( ! _win8Tutorial) {
        _win8Tutorial = [self itemWithIdentifier: @"server_tutorial_title_win8" cellIdentifier: @"DatasheetActionCell"];
        _win8Tutorial.accessoryStyle = DatasheetAccessoryDisclosure;
        _win8Tutorial.segueIdentifier = @"showTutorial";
    }
    return _win8Tutorial;
}


- (DatasheetItem*) winXpTutorial {
    if ( ! _winXpTutorial) {
        _winXpTutorial = [self itemWithIdentifier: @"server_tutorial_title_winxp" cellIdentifier: @"DatasheetActionCell"];
        _winXpTutorial.accessoryStyle = DatasheetAccessoryDisclosure;
        _winXpTutorial.segueIdentifier = @"showTutorial";
    }
    return _winXpTutorial;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue withItem:(DatasheetItem *)item sender:(id)sender {
    TutorialViewController * tutorial = (TutorialViewController*) segue.destinationViewController;
    NSString * tutorialKey;
    if ([item isEqual: self.webTutorial]) {
        tutorialKey = @"webinterface";
    } else if ([item isEqual: self.macTutorial]) {
        tutorialKey = @"webdav_mac";
    } else if ([item isEqual: self.win8Tutorial]) {
        tutorialKey = @"webdav_win8";
    } else if ([item isEqual: self.win7Tutorial]) {
        tutorialKey = @"webdav_win7";
    } else if ([item isEqual: self.winXpTutorial]) {
        tutorialKey = @"webdav_winxp";
    } else {
        NSLog(@"ERROR: unknown webdav tutorial item");
    }

    tutorial.text = [self tutorialForOS: tutorialKey];
}

- (NSAttributedString*) tutorialForOS: (NSString*) name {
    NSURL *rtfPath = [[NSBundle mainBundle] URLForResource: name withExtension:@"rtf"];
    if ( ! rtfPath) {
        NSLog(@"ERROR: webdav tutorial not found: %@", name);
        return nil;
    }
    NSMutableAttributedString * text = [[NSMutableAttributedString alloc]   initWithFileURL: rtfPath options: @{ NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType} documentAttributes: nil error: nil];
    NSString * boxName = HXOLabelledLocalizedString(@"server_nav_title", nil);
    NSString * appName = HXOAppName();

    NSDictionary * userInfo = @{ @"APPNAME" : appName,
                                 @"BOXNAME" : boxName,
                                 @"URL"     : self.server.url,
                                 @"PASSWORD": self.server.password,
                                 @"USER"    : @"hoccer"
                                 };

    NSError * error;
    NSRegularExpression * regex = [[NSRegularExpression alloc] initWithPattern: @"\\$\\{[^\\}]+\\}" options:0 error:&error];
    NSString * rawString = text.string;

    if (error) {
        NSLog(@"Regex error: %@", error);
        return nil;
    }

    NSMutableArray * references = [NSMutableArray array];
    [regex enumerateMatchesInString: rawString options: 0 range: NSMakeRange(0, rawString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [references addObject: [NSValue valueWithRange: result.range]];
    }];

    for (NSValue * value in [references reverseObjectEnumerator]) {
        NSRange referenceRange = [value rangeValue];
        NSRange symbolRange = referenceRange;
        symbolRange.location += 2;
        symbolRange.length -= 3;
        NSString * symbol = [rawString substringWithRange: symbolRange];
        [text replaceCharactersInRange: referenceRange withString: userInfo[symbol]];
    }
    return text;
}
@end
