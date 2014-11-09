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

#import <QuartzCore/QuartzCore.h>


@interface ServerViewController ()

@property (strong, nonatomic) id connectionInfoObserver;

@end


@implementation ServerViewController

@dynamic navigationItem;

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
    
    self.passwordTextField.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
    self.passwordTextField.delegate = self;
    self.statusLabel.text = @"";
    
    self.passwordLabel.text = NSLocalizedString(@"password_title", nil);
    self.urlLabel.text = NSLocalizedString(@"server_adress_title", nil);
    
    NSString * password = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
    if ([password isEqualToString:@"hoccer-pw"]) {
        unsigned long randomNumber = abs(rand())%10000;
        NSString * newPassword = [NSString stringWithFormat:@"miradumo%lu",randomNumber];
        [[HXOUserDefaults standardUserDefaults] setValue:newPassword forKey:kHXOHttpServerPassword];
        [[HXOUserDefaults standardUserDefaults] synchronize];
        
    }
    self.passwordTextField.text = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];
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

- (IBAction)startServer:(id)sender {
    NSLog(@"ServerViewController:startServer");
#ifdef WITH_WEBSERVER
    [AppDelegate.instance startHttpServer];
    [self updateTextFields];
#endif
}

- (IBAction)stopServer:(id)sender {
    NSLog(@"ServerViewController:stopServer");
#ifdef WITH_WEBSERVER
    [AppDelegate.instance stopHttpServer];
    [self updateTextFields];
#endif
}

- (void)textViewDidBeginEditing:(UITextView *)textField {
    [self stopTimer];
}
#ifdef WITH_WEBSERVER


- (void)textViewDidEndEditing:(UITextView *)textField {
    // NSLog(@"textViewDidEndEditing");
    if ([textField isEqual:self.passwordTextField]) {
        NSLog(@"%@",self.passwordTextField.text);
        [[HXOUserDefaults standardUserDefaults] setValue:self.passwordTextField.text forKey:kHXOHttpServerPassword];
        [[HXOUserDefaults standardUserDefaults] synchronize];
        [self updateTextFields];
        [self startTimer];
    }
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textField {
    return YES;
}

- (BOOL)textViewShouldReturn:(UITextView *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)atext {
    NSLog(@"shouldChangeTextInRange");
	
	//weird 1 pixel bug when clicking backspace when textView is empty
	if(![textView hasText] && [atext isEqualToString:@""]) return NO;
    
	if ([atext isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
	}
	
	return YES;
}

static inline NSString * URLEncodedString(NSString *string)
{
	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,  (__bridge CFStringRef)string,  NULL,  CFSTR(":/.?&=;+!@$()~"),  kCFStringEncodingUTF8);
}

-(void)updateTextFields {
    NSDictionary * adresses = AppDelegate.instance.ownIPAddresses;
    NSString * ipV4 = adresses[@"en0/ipv4"];
#ifdef SHOW_DETAIL_STATUS
    NSString * ipV6 = adresses[@"en0/ipv6"];
    NSString * wanIPV4 = adresses[@"pdp_ip0/ipv4"];
    NSString * wanIPV6 = adresses[@"pdp_ip0/ipv6"];
#endif
    BOOL canRun = (ipV4 != nil && ipV4.length > 0);
    
    if (AppDelegate.instance.httpServerIsRunning) {
        HTTPServer * server = AppDelegate.instance.httpServer;
        
        if (!canRun) {
            [AppDelegate.instance stopHttpServer];
            return;
        }
        
        //self.statusTextField.text = NSLocalizedString(@"Server is running", nil);
        int port = server.listeningPort;
#ifdef SHOW_DETAIL_STATUS
        NSString * status = [NSString stringWithFormat:@"Server is running\nIPV4-LAN-Address:%@\nIPV6-LAN-Address:%@\nIPV4-WAN-Address:%@\nIPV6-WAN-Address:%@\nport=%d\nBonjour name=%@\nBonjour domain=%@",ipV4, ipV6, wanIPV4, wanIPV6,port,server.publishedName,server.domain];
        
        self.statusTextField.text = status;
#else
        self.statusTextField.text = NSLocalizedString(@"server_running", nil);
        //NSLog(@"%@",self.statusTextField.text);
#endif
        //self.urlTextField.text = [NSString stringWithFormat:@"IPV4: http://%@:%d/ \nIPV6: http://[%@]:%d/",ipV4,port, ipV6,port];
        self.urlLabel.text = NSLocalizedString(@"server_adress_title", nil);
        self.urlTextField.text = [NSString stringWithFormat:@"http://%@:%d/",ipV4,port];
        self.startButton.enabled = NO;
        self.stopButton.enabled = YES;
    } else {
        self.urlTextField.text = @"";//NSLocalizedString(@"Server is stopped", nil);
        if (canRun) {
            self.statusTextField.text = NSLocalizedString(@"server_stopped_can_run", nil);
        } else {
            self.statusTextField.text = NSLocalizedString(@"server_stopped_can_not_run", nil);
        }
        self.urlLabel.text = @"";
        self.startButton.enabled = canRun;
        self.stopButton.enabled = NO;
    }
    self.passwordTextField.text = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];

}
#endif

@end

