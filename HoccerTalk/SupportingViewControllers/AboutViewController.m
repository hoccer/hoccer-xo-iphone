//
//  AboutViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AboutViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "UIViewController+HoccerTalkSideMenuButtons.h"

@implementation AboutViewController

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hoccerTalkMenuButton];
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];

    self.appIcon.image = [UIImage imageNamed: @"hoccer-talk-app-icon-ipad"];
    self.appIcon.layer.masksToBounds = YES;
    self.appIcon.layer.cornerRadius = 10.0;
    self.appIconShadow.layer.shadowColor = [UIColor blackColor].CGColor;
    self.appIconShadow.layer.shadowOpacity = 0.8;
    self.appIconShadow.layer.shadowOffset = CGSizeMake(0, 3);

    self.scrollView.alwaysBounceVertical = YES;

    self.appName.text = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleDisplayName"];

    NSString * version = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString * buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
    self.appVersionLabel.text = [NSString stringWithFormat: @"Version: %@ – %@", version, buildNumber];
    self.appReleaseName.text = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"HXOReleaseName"];

    float dy = 0;
    dy = [self setLabel: self.aboutProsa toText: NSLocalizedString(@"about_prosa", nil) andUpdateDy: dy];
    [self moveView: self.teamLabel by: dy];

    [self moveView: self.clientDeveloperLabel by: dy];
    [self moveView: self.clientDeveloperList by: dy];
    dy = [self setLabel: self.clientDeveloperList toText: [self peopleListAsText: @"HXOClientDevelopers"] andUpdateDy: dy];

    [self moveView: self.serverDeveloperLabel by: dy];
    [self moveView: self.serverDeveloperList by: dy];
    dy = [self setLabel: self.serverDeveloperList toText: [self peopleListAsText: @"HXOServerDevelopers"] andUpdateDy: dy];

    [self moveView: self.designLabel by: dy];
    [self moveView: self.designList by: dy];
    dy = [self setLabel: self.designList toText: [self peopleListAsText: @"HXODesigners"] andUpdateDy: dy];
}


- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
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

@end
