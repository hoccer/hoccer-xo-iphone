//
//  GesturesInterpreter.m
//  Hoccer
//
//  Created by Robert Palmer on 14.09.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "GesturesInterpreter.h"
#import "NSObject+DelegateHelper.h"
#import "CatchDetector.h"
#import "ThrowDetector.h"
#import "FeatureHistory.h"


@implementation GesturesInterpreter

@synthesize delegate;

static GesturesInterpreter * _instance = nil;

- (id) init
{
	self = [super init];
	if (self != nil) {
		catchDetector = [[CatchDetector alloc] init];
		throwDetector = [[ThrowDetector alloc] init];
		
		featureHistory = [[FeatureHistory alloc] init];
		
	}
	return self;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (void)dealloc 
{
	[UIAccelerometer sharedAccelerometer].delegate = nil;
}

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration 
{
	[featureHistory addAcceleration:acceleration];
	
	if ([catchDetector detect:featureHistory]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"gesturesInterpreterDidDetectCatch"
                                                            object:self
                                                          userInfo:nil];

	} else if ([throwDetector detect: featureHistory]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"gesturesInterpreterDidDetectThrow"
                                                            object:self
                                                          userInfo:nil];
	}	
}

- (void)start {
    [UIAccelerometer sharedAccelerometer].delegate = self;
    [UIAccelerometer sharedAccelerometer].updateInterval = 0.02;
}

- (void)stop {
    [UIAccelerometer sharedAccelerometer].delegate = nil;
}

#pragma clang diagnostic pop


+ (GesturesInterpreter*)instance {
    if (_instance == nil) {
        _instance = [GesturesInterpreter new];
    }
    return _instance;
}

@end
