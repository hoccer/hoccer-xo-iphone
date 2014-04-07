//
//  ServerViewController.h
//  HoccerXO
//
//  Created by PM on 01.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ServerViewController : UIViewController<UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UIButton *startButton;
@property (strong, nonatomic) IBOutlet UIButton *stopButton;

@property (strong, nonatomic) IBOutlet UILabel *urlLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UILabel *passwordLabel;

@property (strong, nonatomic) IBOutlet UITextView * urlTextField;
@property (strong, nonatomic) IBOutlet UITextView * statusTextField;
@property (strong, nonatomic) IBOutlet UITextView * passwordTextField;

@property (strong, nonatomic) IBOutlet UINavigationItem *navigationItem;

@property (strong, nonatomic) NSTimer *updateTimer;

- (IBAction)startServer:(id)sender;
- (IBAction)stopServer:(id)sender;

@end
