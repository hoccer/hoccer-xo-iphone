//
//  NavigationMenuViewController.m
//  HoccerXO
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
    BOOL _viewAppeared;
}
@end

@implementation NavigationMenuViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        _viewControllers = [[NSMutableDictionary alloc] init];
        _viewAppeared = NO;
    }
    return self;
}

- (void) viewDidLoad {
    _menuItems = @[ @{ @"title": NSLocalizedString(@"Chats", nil),
                       @"icon": @"navigation_button_chats",
                       @"storyboardId": @"conversationViewController"
                    },
                    @{ @"title": NSLocalizedString(@"contacts_menu_item", nil),
                       @"icon": @"navigation_button_contacts",
                       @"storyboardId": @"contactsViewController"
                       },
                    @{ @"title": NSLocalizedString(@"Profile", nil),
                       @"icon": @"navigation_button_profile",
                       @"storyboardId": @"profileViewController"
                    },
                    @{ @"title": NSLocalizedString(@"Settings", nil),
                       @"icon": @"navigation_button_settings",
                       @"storyboardId": @"settingsViewController"
                    },
#ifdef HXO_SHOW_UNIMPLEMENTED_FEATURES
                    @{ @"title": NSLocalizedString(@"Tutorial", nil),
                       @"icon": @"navigation_button_tutorial",
                       @"storyboardId": @"tutorialViewController"
                    },
                    @{ @"title": NSLocalizedString(@"FAQ", nil),
                       @"icon": @"navigation_button_faq",
                       @"storyboardId": @"tutorialViewController" // TODO: @"faqViewController"
                       },
#endif
                    @{ @"title": NSLocalizedString(@"About", nil),
                       @"icon": @"navigation_button_about",
                       @"storyboardId": @"aboutViewController"
                    }
                   ];

}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    _viewAppeared = YES;
    [self updateSelectedItem];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_menuItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"navigationMenuCell" forIndexPath:indexPath];
    if (cell.backgroundView == nil) {
        cell.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.backgroundView.frame = cell.frame;
        cell.selectedBackgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg_selected"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.selectedBackgroundView.frame = cell.frame;
    }
    cell.textLabel.text = _menuItems[indexPath.row][@"title"];
    cell.imageView.image = [UIImage imageNamed: _menuItems[indexPath.row][@"icon"]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * storyboardId =  _menuItems[indexPath.row][@"storyboardId"];
    UIViewController * viewController = [self getViewControllerByStoryboardId: storyboardId];
    if ( ! [_menuItems[indexPath.row][@"title"] isEqualToString: @"Chats"]) {
        viewController.title = _menuItems[indexPath.row][@"title"];
    }
    [self.sideMenu.navigationController setViewControllers: @[viewController] animated: NO];
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

- (void) navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (_viewAppeared) {
        [self updateSelectedItem];
    }
}

- (void) updateSelectedItem {
    for (int i = 0; i < _viewControllers.count; ++i) {
        if ([self.sideMenu.navigationController.viewControllers[0] isEqual: _viewControllers[_menuItems[i][@"storyboardId"]]]) {
            NSIndexPath * indexPath = [NSIndexPath indexPathForItem: i inSection: 0];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionBottom];
            return;
        }
    }
    NSLog(@"NavigationMenu failed to find selected view controller");
}

@end
