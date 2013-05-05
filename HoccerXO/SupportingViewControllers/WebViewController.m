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

{
    int _requestsRunning;
}

@synthesize webView = _webView;

- (void) viewDidLoad {
    [super viewDidLoad];
    
    _requestsRunning = 0;

    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];
    
    self.webView.suppressesIncrementalRendering = YES;
    self.webView.delegate = self;
    
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
    // NSLog(@"webview shouldStartLoadWithRequest %@, _requestsRunning = %d", request.URL, _requestsRunning);
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    ++_requestsRunning;
    // NSLog(@"webview webViewDidStartLoad _requestsRunning = %d", _requestsRunning);
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    if (--_requestsRunning == 0) {
        [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
        NSLog(@"webview finshed loading, RNCachingURLProtocol ungregistered");
    }
    // NSLog(@"webview finshed loading, _requestsRunning=%d", _requestsRunning);
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
    if (--_requestsRunning == 0) {
        [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
        NSLog(@"webview failed to load, RNCachingURLProtocol ungregistered");
    }
    // NSLog(@"webview failed to load, _requestsRunning=%d", _requestsRunning);
}

@end
