//
//  CLLocationManager+AuthHelper.h
//  HoccerXO
//
//  Created by David Siegel on 24.09.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

@interface CLLocationManager (AuthHelper)

- (BOOL) performAuthOrRun;
- (BOOL) handleAuthorizationStatus: (CLAuthorizationStatus) status;

@end
