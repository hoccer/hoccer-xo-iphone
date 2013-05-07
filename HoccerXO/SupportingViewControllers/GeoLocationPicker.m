//
//  GeoLocationViewController.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GeoLocationPicker.h"

@interface DnDAnnotation : MKPlacemark {
	CLLocationCoordinate2D coordinate_;
	NSString *title_;
	NSString *subtitle_;
}

// Re-declare MKAnnotation's readonly property 'coordinate' to readwrite.
@property (nonatomic, readwrite, assign) CLLocationCoordinate2D coordinate;

@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subtitle;

@end


@implementation DnDAnnotation

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate addressDictionary:(NSDictionary *)addressDictionary {

	if ((self = [super initWithCoordinate:coordinate addressDictionary:addressDictionary])) {
		self.coordinate = coordinate;
	}
	return self;
}

@end


@interface GeoLocationPicker ()
{
    DnDAnnotation * _annotation;
}

@end

@implementation GeoLocationPicker

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.locationManager.delegate = self;
    self.mapView.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self.locationManager startUpdatingLocation];

    self.useButton.enabled = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    _annotation = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@synthesize locationManager = _locationManager;
- (CLLocationManager*) locationManager {
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

#pragma mark - CLLocationManager Delegate Protocol

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    MKCoordinateRegion region =  MKCoordinateRegionMakeWithDistance(newLocation.coordinate, 500, 500);
    [self.mapView setRegion: region animated: NO];
    [self.locationManager stopUpdatingLocation];

	_annotation = [[DnDAnnotation alloc] initWithCoordinate: newLocation.coordinate addressDictionary:nil];
	_annotation.title = @"Drag the Pin";
	_annotation.subtitle = [NSString	stringWithFormat:@"%f %f", _annotation.coordinate.latitude, _annotation.coordinate.longitude];

	[self.mapView addAnnotation: _annotation];

    self.useButton.enabled = YES;
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {

	if (oldState == MKAnnotationViewDragStateDragging) {
		DnDAnnotation *annotation = (DnDAnnotation *)annotationView.annotation;
		annotation.subtitle = [NSString	stringWithFormat:@"%f %f", annotation.coordinate.latitude, annotation.coordinate.longitude];
	}
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {

    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
	}

	static NSString * const kPinAnnotationIdentifier = @"PinIdentifier";
	MKAnnotationView *draggablePinView = [self.mapView dequeueReusableAnnotationViewWithIdentifier:kPinAnnotationIdentifier];

	if (draggablePinView) {
		draggablePinView.annotation = annotation;
	} else {
		draggablePinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier: kPinAnnotationIdentifier];
		draggablePinView.draggable = YES;
		draggablePinView.canShowCallout = YES;
	}

	return draggablePinView;
}

#pragma mark - Actions

- (IBAction) cancelPressed:(id)sender {
    [self dismissViewControllerAnimated: YES completion: nil];
    [self.delegate locationPickerDidCancel: self];
}

- (IBAction) usePressed:(id)sender {
    [self dismissViewControllerAnimated: YES completion: nil];
    [self.delegate locationPicker: self didPickLocation: _annotation.coordinate];
}


@end
