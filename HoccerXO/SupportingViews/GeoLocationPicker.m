
//
//  GeoLocationViewController.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GeoLocationPicker.h"
#import "UIImage+ScaleAndCrop.h"
#import "HXOUserDefaults.h"
#import "CLLocationManager+AuthHelper.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kGeoLocationCityZoom = 500;


@interface GeoLocationPicker () {
    MKPointAnnotation * _placemark;
}

@end

@implementation GeoLocationPicker

- (void)viewDidLoad {
    [super viewDidLoad];
    self.locationManager.delegate = self;

    self.title = NSLocalizedString(@"geolocation_picker_title", nil);
    self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"cancel", nil);
    self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"done", nil);

    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.mapView.showsUserLocation = YES;

    if ([self.locationManager respondsToSelector: @selector(performAuthOrRun)]) {
        [self.locationManager performAuthOrRun];
    } else {
        [self locationManager: self.locationManager didChangeAuthorizationStatus: kCLAuthorizationStatusAuthorized];
    }

    self.navigationItem.rightBarButtonItem.enabled = NO;
    _renderPreview = NO;
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    [self.mapView removeAnnotation: _placemark];
    _placemark = nil;
    [self.locationManager stopUpdatingLocation];
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
    if (_placemark == nil) {
        MKCoordinateRegion region =  MKCoordinateRegionMakeWithDistance(newLocation.coordinate, kGeoLocationCityZoom, kGeoLocationCityZoom);
        [self.mapView setRegion: region animated: NO];
        _pinDraggedByUser = NO;

        [self dropPin: newLocation.coordinate];
    } else if ( ! _pinDraggedByUser){
        _placemark.coordinate = newLocation.coordinate;
    }
}

- (void) dropPin:(CLLocationCoordinate2D) coordinate {
    _placemark = [[MKPointAnnotation alloc] init];
    _placemark.coordinate = coordinate;
    _placemark.title = @"Here";

    [self.mapView addAnnotation: _placemark];

    self.navigationItem.rightBarButtonItem.enabled = _placemark != nil;
}

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if ([self.locationManager respondsToSelector: @selector(handleAuthorizationStatus:)]) {
        [self.locationManager handleAuthorizationStatus: status];
    }
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)annotationView didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    _pinDraggedByUser = YES;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {

    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
	}

	static NSString * const kPinAnnotationIdentifier = @"PinIdentifier";
	MKPinAnnotationView *draggablePinView = (MKPinAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:kPinAnnotationIdentifier];

	if (draggablePinView) {
		draggablePinView.annotation = annotation;
	} else {
		draggablePinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier: kPinAnnotationIdentifier];
		draggablePinView.draggable = YES;
        //draggablePinView.canShowCallout = YES;
        draggablePinView.animatesDrop = YES;
	}

	return draggablePinView;
}

- (void) mapViewWillStartLoadingMap:(MKMapView *)mapView {
    if (_renderPreview == YES) {
        [NSObject cancelPreviousPerformRequestsWithTarget: self];
    }
}

- (void) mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    if (_renderPreview == YES) {
        [self generateImageFromMap];
    }
    _renderPreview = NO;
}

- (void) mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error {
    if (_renderPreview == YES) {
        [self generateImageFromMap];
    }
    _renderPreview = NO;
}

#pragma mark - Actions

- (IBAction) cancelPressed:(id)sender {
    [self dismissViewControllerAnimated: YES completion: nil];
    [self.delegate locationPickerDidCancel: self];
}

- (IBAction) donePressed:(id)sender {
    [self renderPreview];
}

- (void) renderPreview {
    _renderPreview = YES;
    self.mapView.showsUserLocation = NO;
    [self.mapView deselectAnnotation: _placemark animated: NO];
    MKCoordinateRegion region =  MKCoordinateRegionMakeWithDistance(_placemark.coordinate, kGeoLocationCityZoom, kGeoLocationCityZoom);
    [self.mapView setRegion: region animated: NO];
    [self performSelector:@selector(generateImageFromMap) withObject:nil afterDelay: 0.3];
}

- (void) generateImageFromMap {
    float previewSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOPreviewImageWidth] floatValue];
    UIGraphicsBeginImageContextWithOptions(self.mapView.frame.size, YES, UIScreen.mainScreen.scale);
    [self.mapView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    image = [image imageByScalingAndCroppingForSize: CGSizeMake(previewSize, previewSize)];

    [self.delegate locationPicker: self didPickLocation: _placemark preview: image];
    [self dismissViewControllerAnimated: YES completion: nil];
}

@end
