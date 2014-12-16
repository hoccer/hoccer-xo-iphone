//
//  ServerViewController.m
//  HoccerXO
//
//  Created by PM on 01.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ServerViewController.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "HTTPServer.h"
#import "GCDAsyncSocket.h"
#import "HXOUserDefaults.h"
#import "HXOUI.h"

#import <QuartzCore/QuartzCore.h>


@interface ServerViewController ()

@property (strong, nonatomic) id connectionInfoObserver;

@end


@implementation ServerViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];

    self.serverButton.layer.cornerRadius = kHXOGridSpacing;
    self.serverButton.titleEdgeInsets = UIEdgeInsetsMake(0, kHXOGridSpacing, 0, kHXOGridSpacing);


    //self.passwordTextField.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    //self.passwordTextField.delegate = self;
    self.statusLabel.text = @"x";
    
    self.passwordLabel.text = NSLocalizedString(@"password_title", nil);
    self.urlLabel.text = NSLocalizedString(@"server_adress_title", nil);
    
    NSString * password = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
    if ([password isEqualToString:@"hoccer-pw"]) {
        unsigned long randomNumber = abs(rand())%10000;
        NSString * newPassword = [NSString stringWithFormat:@"miradumo%lu",randomNumber];
        [[HXOUserDefaults standardUserDefaults] setValue:newPassword forKey:kHXOHttpServerPassword];
        [[HXOUserDefaults standardUserDefaults] synchronize];
        
    }
    self.passwordField.text = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
    [self.passwordField addTarget: self action: @selector(passwordDidChange:) forControlEvents: UIControlEventEditingChanged];
    self.passwordField.delegate = self;


    id views = @{ @"tlg": self.topLayoutGuide,
                  @"btn": self.serverButton,
                  @"url": self.urlLabel,
                  @"passwordLabel": self.passwordLabel,
                  @"password": self.passwordField,
                  @"status": self.statusLabel,
                  @"blg": self.bottomLayoutGuide
                  };


    //for (id key in views) { [views[key] setBackgroundColor: [UIColor colorWithWhite: 0.96 alpha: 1]]; }

    //self.urlLabel.backgroundColor = [UIColor orangeColor];
    const double b = 2 *kHXOGridSpacing;
    id format = [NSString stringWithFormat:@"V:|[tlg]-%f-[btn]-%f-[url]-%f-[password]-%f-[status]-(>=%f)-[blg]|",
                 2 * b, b, b, b, b];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    format = [NSString stringWithFormat: @"H:|-(>=%f)-[btn(80)]-(>=%f)-|", b, b];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:format options: 0 metrics: nil views: views]];

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.serverButton attribute: NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    format = [NSString stringWithFormat: @"H:|-%f-[url]-%f-|", b, b];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:format options: 0 metrics: nil views: views]];

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.passwordLabel attribute: NSLayoutAttributeBaseline relatedBy:NSLayoutRelationEqual toItem: self.passwordField attribute: NSLayoutAttributeBaseline multiplier: 1 constant: 0]];
    
    format = [NSString stringWithFormat: @"H:|-%f-[passwordLabel]-[password]-%f-|", b, b];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:format options: 0 metrics: nil views: views]];

    format = [NSString stringWithFormat: @"H:|-%f-[status]-%f-|", b, b];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat:format options: 0 metrics: nil views: views]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void) startTimer {
    // NSLog(@"startTimer:");
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateTextFields) userInfo:nil repeats:YES];
}

- (void) stopTimer {
    // NSLog(@"stopTimer:");
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [HXOBackend broadcastConnectionInfo];
#ifdef WITH_WEBSERVER
    [self updateTextFields];
#endif
    [self startTimer];
}

- (void) viewWillDisappear:(BOOL)animated  {
    [self stopTimer];
}

- (IBAction)toggleServer:(id)sender {
    if (AppDelegate.instance.httpServerIsRunning) {
        [AppDelegate.instance stopHttpServer];
    } else {
        [AppDelegate.instance startHttpServer];
    }
    [self updateTextFields];
}

- (void)textViewDidBeginEditing:(UITextView *)textField {
    [self stopTimer];
}
#ifdef WITH_WEBSERVER


- (void) passwordDidChange: (UITextField*) field {
    NSLog(@"%@",self.passwordField.text);
    [[HXOUserDefaults standardUserDefaults] setValue:self.passwordField.text forKey:kHXOHttpServerPassword];
    [[HXOUserDefaults standardUserDefaults] synchronize];
    [self updateTextFields];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

static inline NSString * URLEncodedString(NSString *string)
{
	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,  (__bridge CFStringRef)string,  NULL,  CFSTR(":/.?&=;+!@$()~"),  kCFStringEncodingUTF8);
}

-(void)updateTextFields {
    NSDictionary * adresses = AppDelegate.instance.ownIPAddresses;
    NSString * ipV4 =
#if ! TARGET_IPHONE_SIMULATOR
    adresses[@"en0/ipv4"];
#else
    adresses[adresses.allKeys.firstObject];  // use any interface (provided by the host) in the simulator
#endif

#ifdef SHOW_DETAIL_STATUS
    NSString * ipV6 = adresses[@"en0/ipv6"];
    NSString * wanIPV4 = adresses[@"pdp_ip0/ipv4"];
    NSString * wanIPV6 = adresses[@"pdp_ip0/ipv6"];
#endif
    BOOL canRun = (ipV4 != nil && ipV4.length > 0);
    BOOL isRunning = AppDelegate.instance.httpServerIsRunning;
    if (isRunning) {
        HTTPServer * server = AppDelegate.instance.httpServer;
        
        if (!canRun) {
            [AppDelegate.instance stopHttpServer];
            return;
        }
        
        //self.statusTextField.text = NSLocalizedString(@"Server is running", nil);
        int port = server.listeningPort;
#ifdef SHOW_DETAIL_STATUS
        NSString * status = [NSString stringWithFormat:@"Server is running\nIPV4-LAN-Address:%@\nIPV6-LAN-Address:%@\nIPV4-WAN-Address:%@\nIPV6-WAN-Address:%@\nport=%d\nBonjour name=%@\nBonjour domain=%@",ipV4, ipV6, wanIPV4, wanIPV6,port,server.publishedName,server.domain];
        
        self.statusLabel.text = status;
#else
        self.statusLabel.text = NSLocalizedString(@"server_running", nil);
        //NSLog(@"%@",self.statusTextField.text);
#endif
        //self.urlTextField.text = [NSString stringWithFormat:@"IPV4: http://%@:%d/ \nIPV6: http://[%@]:%d/",ipV4,port, ipV6,port];
        NSString * url = [NSString stringWithFormat:@"http://%@:%d/",ipV4,port];
        NSString * title = NSLocalizedString(@"server_adress_title", nil);
        NSRange urlRange = NSMakeRange(title.length, url.length);
        NSString * text = [NSString stringWithFormat: @"%@%@", title, url];
        NSMutableAttributedString * str = [[NSMutableAttributedString alloc] initWithString: text];
        [str setAttributes: @{NSFontAttributeName : [UIFont boldSystemFontOfSize: self.urlLabel.font.pointSize]} range: urlRange];
        self.urlLabel.attributedText = str;
        self.serverButton.enabled = YES;
    } else {
        if (canRun) {
            self.statusLabel.text = NSLocalizedString(@"server_stopped_can_run", nil);
        } else {
            self.statusLabel.text = NSLocalizedString(@"server_stopped_can_not_run", nil);
        }
        self.urlLabel.text = @"";
        self.serverButton.enabled = canRun;
    }
    self.serverButton.selected = isRunning;
    self.passwordField.text = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];

}
#endif

@end

