//
//  WebViewController.h
//  HoccerXO
//
//  Created by Pavel Mayer on 05.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIView *loadingOverlay;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

// url is set in the storyboard
@property (strong, nonatomic) NSString * url;

@end
