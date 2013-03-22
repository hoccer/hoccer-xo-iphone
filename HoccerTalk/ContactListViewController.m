//
//  ContactListViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"
#import "ContactCell.h"
#import "BezeledImageView.h"

@interface ContactListViewController ()
{
    NSArray * dummies;
}
@end

@implementation ContactListViewController

- (void) viewDidLoad {
    self.searchBar.backgroundImage = [[UIImage imageNamed: @"searchbar_bg"] resizableImageWithCapInsets:UIEdgeInsetsMake(1, 1, 1, 1)];
    dummies = @[@"Ich", @"Du", @"SieErEs"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [dummies count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    ContactCell *cell = [tableView dequeueReusableCellWithIdentifier: [ContactCell reuseIdentifier]];
    if (cell.backgroundView == nil) {
        // TODO: do this right ...
        cell.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.backgroundView.frame = cell.frame;
        cell.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.2];
    }

    cell.nickName.text = dummies[indexPath.row];
    
    return cell;
}
@end
