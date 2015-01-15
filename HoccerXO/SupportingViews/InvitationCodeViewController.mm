//
//  InvitationCodeViewController.m
//  HoccerXO
//
//  Created by David Siegel on 14.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "InvitationCodeViewController.h"

#import "HXOUI.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "QREncoder.h"
#import "HXOLabel.h"
#import "UIAlertView+BlockExtensions.h"
#import "CopyableUITextField.h"
#import "HXOThemedNavigationController.h"
#import "HXOHyperLabel.h"

@interface InvitationCodeViewController ()

@property (nonatomic, strong)   AVCaptureSession           * captureSession;
@property (nonatomic, strong)   NSMutableDictionary        * codes;
@property (nonatomic, strong)   NSArray                    * codesInView;

@property (nonatomic, strong)   UISegmentedControl         * scanOrGenerateToggle;
@property (nonatomic, strong)   UIToolbar                  * toolbar;
@property (nonatomic, strong)   NSLayoutConstraint         * keyboardHeight;
@property (nonatomic, strong)   UIView                     * qrBackgroundView;
@property (nonatomic, strong)   UIImageView                * qrCodeView;
@property (nonatomic, strong)   CopyableUITextField        * codeTextField;
@property (nonatomic, strong)   AVCaptureVideoPreviewLayer * videoLayer;
@property (nonatomic, strong)   HXOLabel                   * promptLabel;
@property (nonatomic, readonly) HXOBackend                 * chatBackend;

@property (nonatomic, strong)   HXOHyperLabel              * cameraPermissionLabel;

@end

@implementation InvitationCodeViewController

@synthesize chatBackend = _chatBackend;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor lightGrayColor];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action: @selector(donePressed:)];
    NSArray * items = @[NSLocalizedString(@"invite_scan_nav_title", nil), NSLocalizedString(@"invite_generate_nav_title", nil)];
    self.scanOrGenerateToggle = [[UISegmentedControl alloc] initWithItems: items];
    [self.scanOrGenerateToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
    self.navigationItem.titleView = self.scanOrGenerateToggle;



    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];

    [self.view addGestureRecognizer:tap];


    self.toolbar = [[UIToolbar alloc] initWithFrame: CGRectZero];
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview: self.toolbar];


    self.keyboardHeight = [NSLayoutConstraint constraintWithItem: self.view attribute: NSLayoutAttributeBottom relatedBy: NSLayoutRelationEqual toItem: self.toolbar attribute:NSLayoutAttributeBottom multiplier: 1 constant: 0];
    [self.view addConstraint: self.keyboardHeight];

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-[bar]-|" options: 0 metrics: nil views: @{@"bar": self.toolbar}]];

    self.promptLabel = [[HXOLabel alloc] initWithFrame: CGRectZero];
    self.promptLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.promptLabel.font = [HXOUI theme].smallTextFont;
    self.promptLabel.text = NSLocalizedString(@"invite_enter_code_prompt", nil);
    [self.promptLabel sizeToFit];
    [self.toolbar addSubview: self.promptLabel];

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.promptLabel
                                                           attribute:NSLayoutAttributeCenterX
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeCenterX
                                                          multiplier:1.f constant:0.f]];

    UIFont * font = [UIFont systemFontOfSize: 36];
    CGRect frame;
    frame.origin.x = kHXOCellPadding;
    frame.origin.y = kHXOGridSpacing;
    frame.size.height = font.lineHeight;
    self.codeTextField = [[CopyableUITextField alloc] initWithFrame: frame];
    self.codeTextField.translatesAutoresizingMaskIntoConstraints = NO;
    //self.codeTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.codeTextField.font = font;
    self.codeTextField.textAlignment = NSTextAlignmentCenter;
    self.codeTextField.layer.borderColor = [HXOUI theme].messageFieldBorderColor.CGColor;
    self.codeTextField.layer.borderWidth = 1;
    self.codeTextField.layer.cornerRadius = kHXOGridSpacing;
    self.codeTextField.layer.masksToBounds = YES;
    // Wierd issue: Not setting the color twice leaves my iPhone4 with an invisible text field (Works in simulator) :-/
    self.codeTextField.backgroundColor = [UIColor orangeColor];
    self.codeTextField.backgroundColor = [UIColor whiteColor];
    self.codeTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.codeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeTextField.returnKeyType = UIReturnKeySend;
    self.codeTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.codeTextField.delegate = self;
    [self.toolbar addSubview: self.codeTextField];

    NSString * format = [NSString stringWithFormat: @"H:|-%f-[field]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.toolbar addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"field": self.codeTextField}]];

    format = [NSString stringWithFormat: @"V:|-%f-[label(>=%f)]-%f-[field(>=%f)]-%f-|", kHXOGridSpacing, self.promptLabel.font.lineHeight, kHXOGridSpacing, font.lineHeight, kHXOGridSpacing];
    [self.toolbar addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"label": self.promptLabel, @"field": self.codeTextField}]];

    self.qrBackgroundView = [[UIToolbar alloc] initWithFrame: CGRectZero];
    self.qrBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    self.qrBackgroundView.alpha = 0;
    [self.view addSubview: self.qrBackgroundView];

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-[view]-|" options: 0 metrics: nil views: @{@"view": self.qrBackgroundView}]];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.qrBackgroundView attribute: NSLayoutAttributeTop relatedBy: NSLayoutRelationEqual toItem: self.topLayoutGuide attribute: NSLayoutAttributeBottom multiplier: 1 constant: 0]];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.qrBackgroundView attribute: NSLayoutAttributeBottom relatedBy: NSLayoutRelationEqual toItem: self.toolbar attribute: NSLayoutAttributeTop multiplier: 1 constant: -1]];


    self.qrCodeView = [[UIImageView alloc] initWithFrame: CGRectZero];
    self.qrCodeView.contentMode = UIViewContentModeScaleAspectFit;
    self.qrCodeView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.qrBackgroundView addSubview: self.qrCodeView];
    format = [NSString stringWithFormat: @"H:|-%f-[qr]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.qrBackgroundView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"qr": self.qrCodeView}]];
    format = [NSString stringWithFormat: @"V:|-%f-[qr]-(>=%f)-|", kHXOCellPadding, kHXOCellPadding];
    [self.qrBackgroundView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"qr": self.qrCodeView}]];
    //self.qrCodeView.backgroundColor = [UIColor lightGrayColor];

    self.cameraPermissionLabel = [[HXOHyperLabel alloc] initWithFrame: CGRectInset(self.view.bounds, kHXOCellPadding, kHXOCellPadding)];
    self.cameraPermissionLabel.attributedText = HXOLocalizedStringWithLinks(@"permission_denied_camera_qr_scanner", nil);
    self.cameraPermissionLabel.textAlignment = NSTextAlignmentCenter;
    self.cameraPermissionLabel.hidden = YES;
    [self.view addSubview: self.cameraPermissionLabel];
    format = [NSString stringWithFormat: @"H:|-%f-[permission]-%f-|", kHXOCellPadding, kHXOCellPadding];

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"permission": self.cameraPermissionLabel}]];
    format = [NSString stringWithFormat: @"V:|-%f-[permission]-%f-|", kHXOCellPadding, kHXOCellPadding];

    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"permission": self.cameraPermissionLabel}]];


    self.scanOrGenerateToggle.selectedSegmentIndex = 0;

}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    self.codes = nil;
}

- (void) viewWillAppear: (BOOL) animated {
    [super viewWillAppear: animated];
    [self requestCameraAccess];
}

- (void) viewDidDisappear: (BOOL) animated {
    [super viewDidDisappear: animated];
    [self tearDownCaptureSession];
    [self clearCodeView];
}

- (BOOL) shouldAutorotate {
    return NO;
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - Video Capture and (QR) Codes

- (void) requestCameraAccess {
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // Will get here on both iOS 7 & 8 even though camera permissions weren't required
            // until iOS 8. So for iOS 7 permission will always be granted.
            if (granted) {
                // Permission has been granted. Use dispatch_async for any UI updating
                // code because this block may be executed in a thread.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setupCaptureSession];
                });
            }
            self.cameraPermissionLabel.hidden = granted;
        }];
    } else {
        // We are on iOS <= 6. Just do what we need to do.
        [self setupCaptureSession];
    }
}

- (void) setupCaptureSession {

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
        //NSLog(@"Machine readable code types: %@", [[metadataOutput availableMetadataObjectTypes] componentsJoinedByString:@", "]);
        [metadataOutput setMetadataObjectTypes: [metadataOutput availableMetadataObjectTypes]];
    } else {
        NSLog(@"Could not add metadata output.");
    }
    [self.captureSession startRunning];

    self.videoLayer.session = self.captureSession;
}

- (void) tearDownCaptureSession {
    while (self.captureSession.inputs.count > 0) {
        [self.captureSession removeInput: [self.captureSession.inputs lastObject]];
    }
    while (self.captureSession.outputs.count > 0) {
        [self.captureSession removeOutput: [self.captureSession.outputs lastObject]];
    }
    [self.captureSession stopRunning];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (self.codes == nil) {
        self.codes = [NSMutableDictionary dictionary];
    }
    for (AVMetadataObject *metadataObject in metadataObjects) {
        if ( ! [metadataObject isKindOfClass: [AVMetadataMachineReadableCodeObject class]]) {
            // ignore faces, &c.
            continue;
        }

        AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;

        if ( ! self.codes[readableObject.stringValue]) {
            NSURL * url = [NSURL URLWithString: readableObject.stringValue];
            if ([url.scheme isEqualToString: kHXOURLScheme]) {
                [self.chatBackend pairByToken: url.host];
                [self addFlash: readableObject];
            } else {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"invite_no_xo_qr_code_title", nil)
                                                                 message: readableObject.stringValue
                                                         completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alert) {
                                                             if (buttonIndex != alert.cancelButtonIndex) {
                                                                 [[UIApplication sharedApplication] openURL: url];
                                                             }
                                                             [self.codes removeObjectForKey: readableObject.stringValue];
                                                         }
                                                       cancelButtonTitle: nil
                                                       otherButtonTitles: nil];
                if ([url.scheme isEqualToString: @"http"] || [url.scheme isEqualToString: @"https"]) {
                    alert.cancelButtonIndex = [alert addButtonWithTitle: NSLocalizedString(@"cancel", nil)];
                    [alert addButtonWithTitle: NSLocalizedString(@"Open", nil)];
                } else {
                    alert.cancelButtonIndex = [alert addButtonWithTitle: NSLocalizedString(@"ok", nil)];
                }
                [alert show];
            }
            self.codes[readableObject.stringValue] = readableObject;
        }
    }
    self.codesInView = metadataObjects;
}

#pragma mark - UI Actions

- (void) segmentChanged: (UISegmentedControl*) segmentedControl {
    BOOL generate = segmentedControl.selectedSegmentIndex == 1;
    self.promptLabel.text = NSLocalizedString(generate ? @"invite_copy_code_prompt" : @"invite_enter_code_prompt", nil);
    self.codeTextField.text = @"";
    self.codeTextField.enabled = ! generate;
    self.qrCodeView.image = nil;
    self.qrBackgroundView.alpha = generate ? 1 : 0;

    if (generate) {
        [self.chatBackend generatePairingTokenWithHandler: ^(id token) {
            if (token == nil || ! [token isKindOfClass:[NSString class]]) {
                NSLog(@"ERROR: Failed to get invite token: %@", token);
                return;
            }
            if (segmentedControl.selectedSegmentIndex == 1) { // monkey guard
                self.codeTextField.text = token;
                NSString * hxoURL = [NSString stringWithFormat: @"%@://%@", kHXOURLScheme, token];
                DataMatrix * qrMatrix = [QREncoder encodeWithECLevel: QR_ECLEVEL_AUTO version: QR_VERSION_AUTO string: hxoURL];
                [UIView transitionWithView: self.qrCodeView
                                  duration: 0.3f
                                   options: UIViewAnimationOptionTransitionCrossDissolve
                                animations: ^{
                                    self.qrCodeView.image = [QREncoder renderTransparentDataMatrix: qrMatrix imageDimension: self.qrCodeView.bounds.size.width];
                                } completion:nil];
            }
        }];
    }
}

- (void) donePressed: (id) sender {
    if (self.scanOrGenerateToggle.selectedSegmentIndex == 0 && self.codeTextField.text && ! [self.codeTextField.text isEqualToString: @""]) {
        [self.chatBackend pairByToken: self.codeTextField.text];
    }
    self.codeTextField.text = @"";
    self.qrCodeView.image = nil;
    [self dismissViewControllerAnimated: YES completion: nil];
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification*) notification {
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat height = orientation == UIInterfaceOrientationIsPortrait(orientation) ? keyboardFrame.size.height : keyboardFrame.size.width;

    [UIView animateWithDuration: duration delay: 0 options: curve animations:^{
        self.keyboardHeight.constant = height;
        [self.view layoutIfNeeded];
    } completion: nil];

}

- (void)keyboardWillHide:(NSNotification*) notification {
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];

    [UIView animateWithDuration: duration delay: 0 options: curve animations:^{
        self.keyboardHeight.constant = 0;
        [self.view layoutIfNeeded];
    } completion: nil];
    
}

- (void) dismissKeyboard {
    [self.codeTextField resignFirstResponder];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [self.chatBackend pairByToken: textField.text];
    textField.text = @"";
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Code Drawer View

- (void) clearCodeView {
    self.codeTextField.text = nil;
    self.qrCodeView.image = nil;
}

#pragma mark - Outline Rendering & Flashes

- (void) addFlash: (AVMetadataMachineReadableCodeObject*) code {
    CALayer * flash = [CALayer layer];
    [CATransaction begin]; {
        flash.frame = [self.videoLayer rectForMetadataOutputRectOfInterest: code.bounds];
        flash.borderColor = [UIColor whiteColor].CGColor;
        flash.borderWidth = 4;
        [self.view.layer insertSublayer: flash above: self.videoLayer];
    } [CATransaction commit];

    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [flash removeFromSuperlayer];
        }];
        [CATransaction setAnimationDuration: 1];
        flash.opacity = 0.0;
    } [CATransaction commit];
}

- (AVCaptureVideoPreviewLayer*) videoLayer {
    if (! _videoLayer) {
        _videoLayer = [AVCaptureVideoPreviewLayer layerWithSession: nil];
        _videoLayer.frame = self.view.layer.bounds;
        _videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.view.layer insertSublayer: _videoLayer atIndex: 0];
    }
    return _videoLayer;
}

#pragma mark - Attic

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

@end

