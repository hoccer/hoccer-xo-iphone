//
//  HXOEnvironment.h
//  HoccerXO
//
//  Created by PM on 22.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef enum  {
    ACTIVATION_MODE_NONE = 0,
    ACTIVATION_MODE_NEARBY = 1,
    ACTIVATION_MODE_WORLDWIDE =2
} EnvironmentActivationMode;

@class HXOBackend;

@interface HXOEnvironment : NSObject<CLLocationManagerDelegate>

// type of the environment, e.g. nearby
@property (nonatomic, strong) NSString * type;

// name of the environment
@property (nonatomic, strong) NSString * name;

// id of the sending client
@property (nonatomic, strong) NSString * clientId;

// optional group the location is associated with
@property (nonatomic, strong) NSString * groupId;

@property (nonatomic, strong) NSNumber * timestamp;

// indicates what was used on the client to determine the location
@property (nonatomic, strong) NSString * locationType;

// longitude and latitude (in this order!), array of doubles
@property (nonatomic, strong) NSArray * geoLocation;

// accuracy of the location in meters; set to 0 if accuracy not available
@property (nonatomic, strong) NSNumber * accuracy;

// bssids in the vicinity of the client
@property (nonatomic, strong) NSArray * bssids;

// possible other location identifiers
@property (nonatomic, strong) NSArray * identifiers;

// possible other location identifiers
@property (nonatomic, strong) NSString * tag;

// default notification preference for worldwide groups
@property (nonatomic, strong) NSString * notificationPreference;

// time to live in ms for worldwide environment
@property (nonatomic, strong) NSNumber * timeToLive;


+ (HXOEnvironment*)sharedInstance;
+ (BOOL)locationDenied;

- (void)deactivateLocation;
- (void)activateLocation;
- (NSDictionary*) asDictionary;

- (void)setActivation:(EnvironmentActivationMode)activationMode;
- (EnvironmentActivationMode)activationMode;

- (void) updateProperties;

+ (NSNumber*) worldwideTimeToLive;
+ (NSString*) worldwideGroupTag;
+ (NSString*) worldwideNotificationPreferences;
+ (BOOL) worldwideHidden;


@end
