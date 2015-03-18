//
//  AboutViewController.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AboutViewController.h"

#import "Environment.h"
#import "HXOHyperLabel.h"
#import "HXOLocalization.h"
#import "HXOUI.h"
#import "AppDelegate.h"

#ifdef DEBUG
# define kReleaseBuild NO 
#else
# define kReleaseBuild YES
#endif

@interface AboutCell : UITableViewCell

@property (nonatomic,assign) IBOutlet UIImageView   * iconView;
@property (nonatomic,assign) IBOutlet UILabel       * nameLabel;
@property (nonatomic,assign) IBOutlet UILabel       * versionLabel;
@property (nonatomic,assign) IBOutlet HXOHyperLabel * aboutLabel;

@end

@implementation AboutCell

- (void) awakeFromNib {
    NSDictionary * views = @{@"c": self.contentView};
    [self addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[c]|" options: 0 metrics: nil views: views]];
    [self addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[c]|" options: 0 metrics: nil views: views]];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.nameLabel attribute: NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem: self.iconView attribute: NSLayoutAttributeCenterY multiplier: 1 constant: 0]];
    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.versionLabel attribute: NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem: self.iconView attribute: NSLayoutAttributeCenterY multiplier: 1 constant: 0]];
}


@end

@interface AboutViewController ()

@property (nonatomic,strong) AboutCell * sizingCell;

@end


@implementation AboutViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.sizingCell = (AboutCell*)[self.tableView dequeueReusableCellWithIdentifier: @"AboutCell"];

    self.navigationItem.title = HXOLocalizedString(@"about_nav_title", nil, HXOAppName());
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AboutCell * cell = [self.tableView dequeueReusableCellWithIdentifier: @"AboutCell" forIndexPath: indexPath];
    [self configureCell: cell];
    return cell;
}

- (void) configureCell: (AboutCell*) cell {
    cell.iconView.image = [(AppDelegate*)[UIApplication sharedApplication].delegate appIcon];
    cell.iconView.backgroundColor = [UIColor clearColor];
    cell.iconView.layer.cornerRadius = 1.5 * kHXOGridSpacing;
    cell.iconView.layer.masksToBounds = YES;
    cell.iconView.layer.borderColor = [UIColor colorWithWhite: 0 alpha: 0.075].CGColor;
    cell.iconView.layer.borderWidth = 1;
    cell.nameLabel.text = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    cell.versionLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    cell.aboutLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    cell.aboutLabel.preferredMaxLayoutWidth = 320 - 2 * 24;
    cell.aboutLabel.attributedText = [[NSAttributedString alloc] initWithString:HXOLabelledLocalizedString(@"about_prosa", nil)];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    [self configureCell: self.sizingCell];
    CGSize size = [self.sizingCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return ceilf(size.height) + 1;
}

@end
