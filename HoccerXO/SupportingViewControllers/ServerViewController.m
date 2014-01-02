//
//  ServerViewController.m
//  HoccerXO
//
//  Created by PM on 01.01.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ServerViewController.h"
#import "UIViewController+HXOSideMenu.h"
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

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];
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

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
    [HXOBackend broadcastConnectionInfo];
    [self updateTextFields];
}

- (IBAction)startServer:(id)sender {
    NSLog(@"ServerViewController:startServer");
    [AppDelegate.instance startHttpServer];
    [self updateTextFields];
}

- (IBAction)stopServer:(id)sender {
    NSLog(@"ServerViewController:startServer");
    [AppDelegate.instance stopHttpServer];
    [self updateTextFields];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSLog(@"textFieldDidEndEditing");
    if ([textField isEqual:self.passwordTextField]) {
        [[HXOUserDefaults standardUserDefaults] setValue:self.passwordTextField.text forKey:kHXOHttpServerPassword];
        [self updateTextFields];
    }
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)atext {
	
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
    if (AppDelegate.instance.httpServerIsRunning) {
        HTTPServer * server = AppDelegate.instance.httpServer;
        //self.statusTextField.text = NSLocalizedString(@"Server is running", nil);
        NSString * statusFormat = NSLocalizedString(@"Server is running on port=%d, name=%@, adresses=%@", nil);
        self.statusTextField.text = [NSString stringWithFormat:statusFormat, server.listeningPort, server.publishedName, AppDelegate.instance.ownIPAddresses];
        NSLog(@"%@",self.statusTextField.text);

        NSString * encodedName = URLEncodedString(server.publishedName);
        NSString * encodedDomain = URLEncodedString(server.domain);
        self.urlTextField.text = [NSString stringWithFormat:@"http://%@:%d/ http://%@.%@/",[AppDelegate.instance ownIPAddress:YES],server.listeningPort, encodedName, encodedDomain];
    } else {
        self.statusTextField.text = NSLocalizedString(@"Server is stopped", nil);
        self.urlTextField.text = NSLocalizedString(@"Server is stopped", nil);
    }
    self.passwordTextField.text = [[HXOUserDefaults standardUserDefaults] valueForKey:kHXOHttpServerPassword];

}


@end

