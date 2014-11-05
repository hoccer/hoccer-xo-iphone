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

@interface AboutViewController ()

@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@end


@implementation AboutViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.scrollView.alwaysBounceVertical = YES;

    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"]];
    NSString *iconName = [[infoPlist valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"] lastObject];
    if ([UIScreen mainScreen].scale == 2) {
        iconName = [iconName stringByAppendingString:@"@2x"];
    }
    NSURL *iconURL = [[NSBundle mainBundle] URLForResource:iconName withExtension:@"png"];
    UIImageView * appIcon = [[UIImageView alloc] initWithImage: [UIImage imageWithData: [NSData dataWithContentsOfURL: iconURL] scale: [UIScreen mainScreen].scale]];
    appIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview: appIcon];

    HXOHyperLabel * appInfo = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
    appInfo.translatesAutoresizingMaskIntoConstraints = NO;
    appInfo.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    appInfo.attributedText = [self appInfoString: infoPlist];
    [self.scrollView addSubview: appInfo];

    HXOHyperLabel * aboutProsa = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
    aboutProsa.translatesAutoresizingMaskIntoConstraints = NO;
    aboutProsa.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    aboutProsa.attributedText = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"about_prosa", nil) attributes: nil];
    [self.scrollView addSubview: aboutProsa];

#ifdef SHOW_PEOPLE
    UILabel * teamLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    teamLabel.translatesAutoresizingMaskIntoConstraints = NO;
    teamLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleHeadline];
    teamLabel.text = NSLocalizedString(@"about_team_heading", nil);
    [self.scrollView addSubview: teamLabel];
#endif
    NSMutableDictionary * views = [NSMutableDictionary dictionaryWithDictionary:
                                   @{@"icon":  appIcon,
                                     @"info":  appInfo,
                                     @"prosa": aboutProsa,
                                     //@"team":  teamLabel
                                     }];
    NSString * format;
#ifdef SHOW_PEOPLE
    NSDictionary * sections = @{@"about_client_developers": @"HXOClientDevelopers",
                                @"about_server_developers": @"HXOServerDevelopers",
                                @"about_designers"        : @"HXODesigners"
//                                @"about_operators"        : @"HXOOperators"
                                };
    UIFontDescriptor * bold = [[UIFontDescriptor preferredFontDescriptorWithTextStyle: UIFontTextStyleBody] fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
    
    for (NSString * labelKey in sections) {
        UILabel  * sectionTitle = [[UILabel alloc] initWithFrame: CGRectZero];
        sectionTitle.translatesAutoresizingMaskIntoConstraints = NO;
        sectionTitle.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
        sectionTitle.text = NSLocalizedString(labelKey, nil);
        [self.scrollView addSubview: sectionTitle];
        views[labelKey] = sectionTitle;

        NSString * infoKey = sections[labelKey];
        UILabel * peopleList = [[UILabel alloc] initWithFrame: CGRectZero];
        peopleList.translatesAutoresizingMaskIntoConstraints = NO;
        peopleList.font = [UIFont fontWithDescriptor: bold size: sectionTitle.font.pointSize];
        peopleList.numberOfLines = 0;
        peopleList.text = [self peopleListAsText: infoKey];
        [self.scrollView addSubview: peopleList];
        views[infoKey] = peopleList;

        format = [NSString stringWithFormat: @"H:|-%f-[%@]-%f-[%@]-%f-|", kHXOCellPadding, labelKey, kHXOCellPadding, infoKey, kHXOCellPadding];
        [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

        [self.scrollView addConstraint: [NSLayoutConstraint constraintWithItem: sectionTitle attribute: NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem: peopleList attribute: NSLayoutAttributeTop multiplier: 1 constant: 0]];
    }
#endif
    
    format = [NSString stringWithFormat: @"H:|-%f-[icon]-%f-[info]-(>=%f)-|", kHXOCellPadding, kHXOCellPadding, kHXOCellPadding];
    [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    format = [NSString stringWithFormat: @"H:|-%f-[prosa]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
#ifdef SHOW_PEOPLE
    format = [NSString stringWithFormat: @"H:|-%f-[team]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
#endif
    format = [NSString stringWithFormat: @"V:|-%f-[icon]", kHXOCellPadding];
    [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
#ifdef SHOW_PEOPLE

    format = [NSString stringWithFormat: @"V:|-%f-[info]-%f-[prosa]-%f-[team]-%f-[HXOClientDevelopers]-%f-[HXOServerDevelopers]-%f-[HXODesigners]-%f-|", kHXOCellPadding, kHXOCellPadding, kHXOCellPadding, kHXOCellPadding, kHXOCellPadding, kHXOCellPadding, kHXOCellPadding];
#else
    format = [NSString stringWithFormat: @"V:|-%f-[info]-%f-[prosa]-%f-|", kHXOCellPadding, kHXOCellPadding, kHXOCellPadding];
#endif
    [self.scrollView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
}


- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
}

- (void) moveView: (UIView*) view by: (float) dy {
    CGRect frame = view.frame;
    frame.origin.y += dy;
    view.frame = frame;
}

- (float) setLabel: (UILabel*) label toText: (NSString*) text andUpdateDy: (float) dy {
    dy -= label.frame.size.height;
    label.text = text;
    [label sizeToFit];
    dy += label.frame.size.height;
    return dy;
}

- (NSString*) peopleListAsText: (NSString*) plistKey {
    NSArray * people = [[NSBundle mainBundle] objectForInfoDictionaryKey: plistKey];
    return [people componentsJoinedByString:@"\n"];
}

- (NSAttributedString*) appInfoString: (NSDictionary*) infoPlist {
    NSMutableAttributedString * appInfo = [[NSMutableAttributedString alloc] initWithString: infoPlist[@"CFBundleDisplayName"] attributes: @{NSFontAttributeName: [UIFont boldSystemFontOfSize: 14]}];

    NSString * releaseString = infoPlist[@"HXOReleaseName"];
    if ( ! [[Environment sharedEnvironment].currentEnvironment isEqualToString: @"production"] || ! kReleaseBuild) {
        releaseString = [NSString stringWithFormat: @"%@\n%@ – %@", releaseString, [Environment sharedEnvironment].currentEnvironment, kReleaseBuild ? @"release" : @"debug"];
    }
    NSString * versionString = [NSString stringWithFormat: @"\nVersion: %@ - %@\n%@", infoPlist[@"CFBundleShortVersionString"], infoPlist[@"CFBundleVersion"], releaseString];
    [appInfo appendAttributedString: [[NSAttributedString alloc] initWithString: versionString attributes: @{NSFontAttributeName: [UIFont systemFontOfSize: 14]}]];

    return appInfo;
}

@end
