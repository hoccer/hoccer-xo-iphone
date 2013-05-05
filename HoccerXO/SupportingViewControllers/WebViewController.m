//
//  WebViewController.m
//  HoccerXO
//
//  Created by Pavel Mayer on 05.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "WebViewController.h"
#import "UIViewController+HXOSideMenuButtons.h"
#import "RNCachingURLProtocol.h"

@implementation WebViewController

@synthesize webView = _webView;

- (void) viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];
    
    NSLog(@"webview opening, registering RNCachingURLProtocol");
    // we will only register the caching protocol for the first page
    [NSURLProtocol registerClass:[RNCachingURLProtocol class]];
    
    NSURL *url = [NSURL URLWithString:self.url];
    NSURLRequest *requestURL = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:requestURL];
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}


#pragma mark - Optional UIWebViewDelegate delegate methods
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
    NSLog(@"webview finshed loading, RNCachingURLProtocol ungregistered");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
    NSLog(@"webview failed to load, RNCachingURLProtocol ungregistered");
}

@end
