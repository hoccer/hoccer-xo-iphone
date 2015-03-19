//
//  TutorialViewController.m
//  HoccerXO
//
//  Created by David Siegel on 19.03.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "TutorialViewController.h"

@interface TutorialViewController ()

@end

@implementation TutorialViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.textView.alwaysBounceVertical = YES;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    self.textView.attributedText = self.text;
}

@end
