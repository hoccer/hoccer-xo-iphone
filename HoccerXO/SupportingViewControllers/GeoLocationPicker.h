//
//  GeoLocationViewController.h
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@class GeoLocationPicker;

@protocol GeoLocationPickerDelegate <NSObject>

- (void) locationPicker: (GeoLocationPicker*) picker didPickLocation: (CLLocationCoordinate2D) coordinate;
- (void) locationPickerDidCancel:(GeoLocationPicker*)picker;

@end

@interface GeoLocationPicker : UIViewController <CLLocationManagerDelegate,MKMapViewDelegate>

@property (strong, nonatomic) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *useButton;
@property (readonly, nonatomic) CLLocationManager * locationManager;

@property (nonatomic, assign) id<GeoLocationPickerDelegate> delegate;

@end
