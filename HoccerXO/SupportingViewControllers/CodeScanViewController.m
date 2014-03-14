//
//  CodeScanViewController.m
//  HoccerXO
//
//  Created by David Siegel on 14.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CodeScanViewController.h"

@interface CodeScanViewController ()

@property (nonatomic,strong) AVCaptureSession * captureSession;
@property (nonatomic,strong) NSMutableDictionary * codes;

@end

@implementation CodeScanViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.captureSession = [[AVCaptureSession alloc] init];
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
    if ([self.captureSession canAddInput:videoInput]) {
        [self.captureSession addInput:videoInput];
    } else {
        NSLog(@"Could not add video input: %@", [error localizedDescription]);
    }

    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];

    if ([self.captureSession canAddOutput:metadataOutput]) {
        [self.captureSession addOutput:metadataOutput];

        [metadataOutput setMetadataObjectsDelegate: self queue: dispatch_get_main_queue()];
        for (id type in [metadataOutput availableMetadataObjectTypes]) {
            NSLog(@"type: %@", type);
        }
        [metadataOutput setMetadataObjectTypes: [metadataOutput availableMetadataObjectTypes]];
    } else {
        NSLog(@"Could not add metadata output.");
    }

    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession: self.captureSession];
    previewLayer.frame = self.view.layer.bounds;
    [self.view.layer addSublayer:previewLayer];

    [self.captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (self.codes == nil) {
        self.codes = [NSMutableDictionary dictionary];
    }
    NSLog(@"===================");
    for (AVMetadataObject *metadataObject in metadataObjects) {
        AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;

        if ( ! self.codes[readableObject.stringValue]) {
            NSLog(@"%@", readableObject.stringValue);
        }
        self.codes[readableObject.stringValue] = readableObject;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    self.codes = nil;
}

@end
