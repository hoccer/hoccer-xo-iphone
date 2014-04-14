//
//  HXOEnvironment.m
//  HoccerXO
//
//  Created by PM on 22.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOEnvironment.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "UserProfile.h"

@interface HXOEnvironment ()
{
    CLLocationManager * _locationManager;
    CLLocation * _lastLocation;
    NSDate * _lastLocationUpdate;
    HXOBackend * _chatBackend;
}
@end

@implementation HXOEnvironment


static NSString * LOCATION_TYPE_GPS = @"gps";         // location from gps
static NSString * LOCATION_TYPE_WIFI = @"wifi";       // location from wifi triangulation
static NSString * LOCATION_TYPE_NETWORK = @"network"; // location provided by cellular network (cell tower)
static NSString * LOCATION_TYPE_MANUAL = @"manual";   // location was set by user
static NSString * LOCATION_TYPE_OTHER = @"other";
static NSString * LOCATION_TYPE_NONE = @"none";       // indicates that location is invalid

#define LOCATION_DEBUG NO

static HXOEnvironment *instance;

+ (HXOEnvironment*)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HXOEnvironment alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    
    return self;
}

- (void)deactivateLocation{
    if (LOCATION_DEBUG) {NSLog(@"Environment: stopUpdatingLocation");}
    [_locationManager stopUpdatingLocation];
}
- (void)activateLocation{
    if (LOCATION_DEBUG) {NSLog(@"Environment: startUpdatingLocation");}
    [_locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation {
    if (_lastLocation == nil) {
        _lastLocation = oldLocation;
    }
    double distance = [newLocation distanceFromLocation:_lastLocation];
    double lastUpdateAgo = [_lastLocationUpdate timeIntervalSinceNow];
    if (LOCATION_DEBUG) {NSLog(@"Environment:didUpdateToLocation: distance change = %f, last update %f secs ago, accuracy %f, last accuracy %f", distance, lastUpdateAgo, newLocation.horizontalAccuracy, _lastLocation.horizontalAccuracy);}
    
	if (distance > 10 ||  lastUpdateAgo < -30 || newLocation.horizontalAccuracy < _lastLocation.horizontalAccuracy || _lastLocationUpdate == nil) {
        _lastLocationUpdate = [NSDate date];
        _lastLocation = newLocation;
        [self sendEnvironmentUpdate];
    } else {
        if (LOCATION_DEBUG) {NSLog(@"Environment:didUpdateToLocation: distance change too small, last update too recent, accuracy not improved");}
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
    if (error.code == kCLErrorDenied){
        UIAlertView *locationAlert = [[UIAlertView alloc]initWithTitle:NSLocalizedString(@"Title_LocationDidFail", nil) message:NSLocalizedString(@"Message_LocationDidFail", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Button_OK", nil) otherButtonTitles:nil, nil];
        [locationAlert show];
    }
}

- (HXOBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }
    
    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;
    
}

- (void) sendEnvironmentUpdate {
    [[self chatBackend] sendLocationUpdate];
}

- (void) updateProperties {
    self.clientId = [UserProfile sharedProfile].clientId;
    self.timestamp = [HXOBackend millisFromDate:_lastLocationUpdate];
    
    self.locationType = LOCATION_TYPE_GPS;
    
    // longitude and latitude (in this order!), array of doubles
    NSMutableArray * myGeoLocation = [[NSMutableArray alloc] init];
    [myGeoLocation addObject:[NSNumber numberWithDouble:_lastLocation.coordinate.longitude]];
    [myGeoLocation addObject:[NSNumber numberWithDouble:_lastLocation.coordinate.latitude]];
    self.geoLocation = myGeoLocation;
    
    // accuracy of the location in meters; set to 0 if accuracy not available
    self.accuracy = [NSNumber numberWithFloat:_lastLocation.horizontalAccuracy];
    
    // bssids in the vicinity of the client
    // NSArray * bssids;
    
    // possible other location identifiers
    // NSArray * identifiers;
}

- (NSDictionary*) asDictionary {
    [self updateProperties];
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithDictionary:
                                    @{ @"clientId" : self.clientId,
                               @"timestamp" : self.timestamp,
                               @"locationType" : self.locationType,
                               @"geoLocation" : self.geoLocation,
                               @"accuracy" : self.accuracy}];
    if (self.groupId != nil) {
        result[@"groupId"] = self.groupId;
    }
    return result;
}


@end
