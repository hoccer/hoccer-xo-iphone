//
//  StudentIdViewController.m
//  HoccerXO
//
//  Created by David Siegel on 20.04.17.
//  Copyright © 2017 Hoccer GmbH. All rights reserved.
//

#import "StudentIdViewController.h"
#import "WebViewController.h"
#import "HXOLocalization.h"

@interface StudentIdViewController ()

@property IBOutlet UIImageView * imageView;
@property IBOutlet UIImageView * bannerView;

@end

@implementation StudentIdViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = HXOLabelledFullyLocalizedString(@"uniheld_student_id_title", nil);
    self.bannerView.image = [UIImage imageNamed: @"uniheld-banner"];

    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [infoButton addTarget:self action:@selector(showInfo:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.imageView.image = self.image;
}

- (void) showInfo: (id) sender {
    NSLog(@"SHOW INFO");
    [self performSegueWithIdentifier: @"showStudentIdInfo" sender: self];
}


- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString: @"showStudentIdInfo"]) {
        WebViewController * vc = (WebViewController*) segue.destinationViewController;
        vc.homeUrl = HXOLabelledFullyLocalizedString(@"uniheld_student_id_info_url", nil);
    }
}
@end
