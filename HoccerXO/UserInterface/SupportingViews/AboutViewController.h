//
//  AboutViewController.h
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AboutViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView *appIcon;
@property (strong, nonatomic) IBOutlet UILabel *appName;
@property (strong, nonatomic) IBOutlet UILabel *appVersionLabel;
@property (strong, nonatomic) IBOutlet UILabel *appReleaseName;

@property (strong, nonatomic) IBOutlet UILabel *aboutProsa;

@property (strong, nonatomic) IBOutlet UILabel *teamLabel;
@property (strong, nonatomic) IBOutlet UILabel *clientDeveloperLabel;
@property (strong, nonatomic) IBOutlet UILabel *clientDeveloperList;
@property (strong, nonatomic) IBOutlet UILabel *serverDeveloperLabel;
@property (strong, nonatomic) IBOutlet UILabel *serverDeveloperList;
@property (strong, nonatomic) IBOutlet UILabel *designLabel;
@property (strong, nonatomic) IBOutlet UILabel *designList;

@property (strong, nonatomic) IBOutlet UIView *appIconShadow;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (strong, nonatomic) IBOutlet UIView *scrolledContent;
@end
