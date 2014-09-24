//
//  CLLocationManager+AuthHelper.m
//  HoccerXO
//
//  Created by David Siegel on 24.09.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CLLocationManager+AuthHelper.h"


@implementation CLLocationManager (AuthHelper)

- (BOOL) performAuthOrRun {
    if ([self respondsToSelector: @selector(requestWhenInUseAuthorization)])
    {
        if (self.class.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
            [self requestWhenInUseAuthorization];
        } else if (self.class.authorizationStatus == kCLAuthorizationStatusDenied) {
            return NO;
        } else {
            [self startUpdatingLocation];
        }
    } else {
        [self startUpdatingLocation];
    }
    return YES;
}

- (BOOL) handleAuthorizationStatus: (CLAuthorizationStatus) status {
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            // happens when assigning the delegate
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorized:
            [self startUpdatingLocation];
            break;
        case kCLAuthorizationStatusDenied:
            [self stopUpdatingLocation];
            return NO;
            break;
        //case kCLAuthorizationStatusAuthorizedAlways:
        default:
            NSLog(@"Unhandled CLAuthorizationStatus: %d", status);
            break;
    }
    return YES;
}

@end
