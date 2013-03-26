//
//  NavigationMenuViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NavigationMenuViewController.h"
#import "MFSideMenu.h"

@interface NavigationMenuViewController ()
{
    NSArray * _menuItems;
    NSMutableDictionary * _viewControllers;
}
@end

@implementation NavigationMenuViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        _viewControllers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) viewDidLoad {
    _menuItems = @[ @{ @"title": @"Conversations", @"storyboardId": @"conversationViewController"},
                   @{ @"title": @"Profile", @"storyboardId": @"profileViewController"}
                   ];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_menuItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"navigationMenuCell"];
    cell.textLabel.text = _menuItems[indexPath.row][@"title"];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"selected: %@ %@", _menuItems[indexPath.row][@"storyboardId"], self.sideMenu);

    NSString * storyboardId =  _menuItems[indexPath.row][@"storyboardId"];
    UIViewController * viewController = [self getViewControllerByStoryboardId: storyboardId];
    NSArray *controllers = [NSArray arrayWithObject: viewController];
    self.sideMenu.navigationController.viewControllers = controllers;
    
    [self.sideMenu setMenuState:MFSideMenuStateClosed];
}

- (void) cacheViewController: (UIViewController*) viewController withStoryboardId: (NSString*) storyboardId{
    _viewControllers[storyboardId] = viewController;
}

- (UIViewController*) getViewControllerByStoryboardId: (NSString*) storyboardID {
    if (_viewControllers[storyboardID] != nil) {
        return _viewControllers[storyboardID];
    }
    UIViewController * vc = _viewControllers[storyboardID] = [self.storyboard instantiateViewControllerWithIdentifier: storyboardID];
    return vc;
}

@end
