//
//  WebViewController.m
//  HoccerXO
//
//  Created by Pavel Mayer on 05.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "WebViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "UIViewController+HXOSideMenu.h"
#import "RNCachingURLProtocol.h"
#import "HXOBackend.h"

@interface WebViewController ()

@property (strong, nonatomic) id connectionInfoObserver;

@end

@implementation WebViewController

{
    int _requestsRunning;
}

@synthesize webView = _webView;

- (void) viewDidLoad {
    [super viewDidLoad];
    
    _requestsRunning = 0;

    //self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    //self.navigationItem.rightBarButtonItem = [self hxoContactsButton];
    
    self.webView.suppressesIncrementalRendering = YES;
    self.webView.delegate = self;

    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];

    self.loadingOverlay.layer.cornerRadius = 8;
    self.loadingOverlay.layer.masksToBounds = YES;
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    
    NSString * myLocalizedUrlString = NSLocalizedString(self.homeUrl,"@webview");
    //NSLog(@"webview url: %@, localized url: %@", self.homeUrl, myLocalizedUrlString);
    
    if (![[self.webView.request.URL absoluteString] isEqualToString:myLocalizedUrlString] ) {
        // in case the user has navigated somewhere else
        [self startFirstLoading];
    }
    [HXOBackend broadcastConnectionInfo];
}

- (void) startFirstLoading {
    [self.activityIndicator startAnimating];
    self.loadingOverlay.hidden = false;
    self.loadingLabel.text = NSLocalizedString(@"Loading", @"webview");
    
    NSLog(@"webview opening, registering RNCachingURLProtocol");
    // we will only register the caching protocol for the first page
    [NSURLProtocol registerClass:[RNCachingURLProtocol class]];
    
    NSString * myLocalizedUrlString = NSLocalizedString(self.homeUrl,"@webview");
    //NSLog(@"webview 2 url: '%@', localized url: '%@'", self.homeUrl, myLocalizedUrlString);
    NSURL *url = [NSURL URLWithString:myLocalizedUrlString];
    //NSLog(@"webview 2 requestURL=%@", url);
    NSURLRequest *requestURL = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:requestURL];
}

- (void) loadingFinished {
    [self.activityIndicator stopAnimating];
    self.loadingOverlay.hidden = true;
    [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
    NSLog(@"webview finshed loading, RNCachingURLProtocol ungregistered");
}

#pragma mark - Optional UIWebViewDelegate delegate methods
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"webview shouldStartLoadWithRequest %@, _requestsRunning = %d", request.URL, _requestsRunning);
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
    if (_requestsRunning && --_requestsRunning == 0) {
        [self loadingFinished];
    }
    // NSLog(@"webview finshed loading, _requestsRunning=%d", _requestsRunning);
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [NSURLProtocol unregisterClass:[RNCachingURLProtocol class]];
    if (_requestsRunning && --_requestsRunning == 0) {
        [self loadingFinished];
    }
    // NSLog(@"webview failed to load, _requestsRunning=%d", _requestsRunning);
}

@end
