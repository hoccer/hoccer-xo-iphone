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
#import "HXOUI.h"

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

    self.navigationItem.title = NSLocalizedString(@"about_nav_title", nil);
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AboutCell * cell = [self.tableView dequeueReusableCellWithIdentifier: @"AboutCell" forIndexPath: indexPath];
    [self configureCell: cell];
    return cell;
}

- (void) configureCell: (AboutCell*) cell {
    cell.iconView.image = [self appIcon];
    cell.iconView.backgroundColor = [UIColor clearColor];
    cell.iconView.layer.cornerRadius = 1.5 * kHXOGridSpacing;
    cell.iconView.layer.masksToBounds = YES;
    cell.iconView.layer.borderColor = [UIColor colorWithWhite: 0 alpha: 0.075].CGColor;
    cell.iconView.layer.borderWidth = 1;
    cell.nameLabel.text = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    cell.versionLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

    cell.aboutLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    cell.aboutLabel.preferredMaxLayoutWidth = 320 - 2 * 24;
    cell.aboutLabel.attributedText = [[NSAttributedString alloc] initWithString:
#ifdef DEBUG
    @"HOCCER - Der Messenger\n\n"
    "Tootsie roll bear claw pastry. Muffin candy chocolate cake powder powder. Marzipan chocolate cake lollipop candy. Soufflé brownie wafer biscuit marshmallow. Marzipan unerdwear.com pudding toffee liquorice. Icing wafer sweet roll cotton candy wafer sweet roll pudding unerdwear.com cheesecake. Macaroon donut danish. Cheesecake applicake candy canes chocolate cake cake chocolate bar cheesecake candy pie.\n\n"
    "Pastry donut tiramisu halvah cotton candy dessert bonbon. Lollipop candy canes wafer candy ice cream. Dragée dragée apple pie topping chocolate sweet wafer cheesecake. Soufflé croissant cookie muffin donut liquorice wafer. Soufflé unerdwear.com biscuit chocolate bar sesame snaps halvah. Bear claw fruitcake halvah tiramisu ice cream. Carrot cake caramels topping jelly-o sugar plum bonbon danish."
#else
    NSLocalizedString(@"about_prosa", nil)
#endif
                                      ];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    [self configureCell: self.sizingCell];
    CGSize size = [self.sizingCell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return ceilf(size.height) + 1;
}

- (UIImage*) appIcon {
    NSArray * names = [[NSBundle mainBundle] infoDictionary][@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    UIImage * best;
    for (NSString * name in names) {
        UIImage * icon = [UIImage imageNamed: name];
        best = icon.size.width > best.size.width ? icon : best;
    }
    return best;
}

@end
