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
#import "CopyableLabel.h"
#import "QREncoder.h"
#import "HXOLabel.h"
#import "UIAlertView+BlockExtensions.h"

@interface InvitationCodeViewController ()

@property (nonatomic, strong)   AVCaptureSession           * captureSession;
@property (nonatomic, strong)   NSMutableDictionary        * codes;
@property (nonatomic, strong)   NSArray                    * codesInView;

@property (nonatomic, strong)   UIScrollView               * drawerScrollView;
@property (nonatomic, strong)   UIView                     * codeDrawerView;
@property (nonatomic, strong)   UIView                     * drawerHandleView;
@property (nonatomic, strong)   UIView                     * headerView;
@property (nonatomic, strong)   UIImageView                * qrCodeView;
@property (nonatomic, strong)   CopyableLabel              * codeLabel;
@property (nonatomic, strong)   UILabel                    * codeDrawerTitle;
@property (nonatomic, strong)   AVCaptureVideoPreviewLayer * videoLayer;
@property (nonatomic, strong)   HXOLabel                   * statusText;
@property (nonatomic, readonly) HXOBackend                 * chatBackend;
@property (nonatomic, assign)   BOOL                         isDrawerExtended;

@end

@interface PullUpView : UIScrollView

@end

@implementation InvitationCodeViewController

@synthesize chatBackend = _chatBackend;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor lightGrayColor];

    CGFloat headerHeight = 4 * kHXOGridSpacing;
    self.headerView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, headerHeight)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = [UIColor colorWithWhite: 0 alpha: 0.3];
    [self.view addSubview: self.headerView];

    CGFloat contentWidth = self.view.bounds.size.width - 2 * kHXOCellPadding;
    self.codeDrawerTitle = [[UILabel alloc] initWithFrame: CGRectZero];
    self.codeDrawerTitle.text = NSLocalizedString(@"invite_code_sheet_title", nil);
    self.codeDrawerTitle.textAlignment = NSTextAlignmentCenter;
    self.codeDrawerTitle.font = [UIFont systemFontOfSize: 18];
    //self.codeDrawerTitle.textColor = [HXOUI theme].smallBoldTextColor;
    [self.codeDrawerTitle sizeToFit];
    CGRect frame = self.codeDrawerTitle.frame;
    frame.size.width = contentWidth;
    frame.origin.x = kHXOCellPadding;
    frame.origin.y = self.headerView.bounds.size.height + kHXOCellPadding;
    self.codeDrawerTitle.frame = frame;

    CGFloat y = self.codeDrawerTitle.frame.origin.y + self.codeDrawerTitle.frame.size.height;
    y += kHXOCellPadding;

    self.qrCodeView = [[UIImageView alloc] initWithFrame: CGRectMake(kHXOCellPadding, y, contentWidth, contentWidth)];
    //self.qrCodeView.backgroundColor = [UIColor lightGrayColor];

    y += self.qrCodeView.frame.size.height + kHXOCellPadding;

    self.codeLabel = [[CopyableLabel alloc] initWithFrame: CGRectZero];
    self.codeLabel.font = [UIFont systemFontOfSize: 36];
    self.codeLabel.text = @"0123456789";
    [self.codeLabel sizeToFit];
    self.codeLabel.text = @"";
    frame = self.codeLabel.frame;
    frame.origin.x = kHXOCellPadding;
    frame.origin.y = y;
    frame.size.width = contentWidth;
    frame.size.height += kHXOGridSpacing;
    self.codeLabel.frame = frame;
    self.codeLabel.textAlignment = NSTextAlignmentCenter;
    self.codeLabel.userInteractionEnabled = YES;
    UIGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(codeLabelTapped:)];
    [self.codeLabel addGestureRecognizer: tapGesture];
    self.codeLabel.backgroundColor = [UIColor whiteColor];
    self.codeLabel.layer.borderColor = [HXOUI theme].messageFieldBorderColor.CGColor;
    self.codeLabel.layer.borderWidth = 1;
    self.codeLabel.layer.cornerRadius = kHXOGridSpacing;
    self.codeLabel.layer.masksToBounds = YES;

    y += self.codeLabel.frame.size.height;


    CGFloat codeViewHeight = y + headerHeight;

    self.drawerScrollView = [[PullUpView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, codeViewHeight)];
    self.drawerScrollView.delegate = self;
    self.drawerScrollView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.drawerScrollView.bounces = NO;
    self.drawerScrollView.pagingEnabled = YES;
    self.drawerScrollView.showsVerticalScrollIndicator = NO;
    self.drawerScrollView.layer.masksToBounds = NO;
    self.drawerScrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 2 * self.drawerScrollView.bounds.size.height);
    self.drawerScrollView.contentOffset = CGPointMake(0, self.drawerScrollView.bounds.size.height);
    //self.drawerScrollView.backgroundColor = [UIColor orangeColor];
    [self.view addSubview: self.drawerScrollView];
    //[self.view sendSubviewToBack: self.drawerScrollView];
    [self.view bringSubviewToFront: self.headerView];

    self.codeDrawerView = [[UIToolbar alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, codeViewHeight)];
    self.codeDrawerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.drawerScrollView addSubview: self.codeDrawerView];
    [self.codeDrawerView addSubview: self.codeDrawerTitle];
    [self.codeDrawerView addSubview: self.qrCodeView];
    [self.codeDrawerView addSubview: self.codeLabel];

    UIButton * doneButton = [UIButton buttonWithType: UIButtonTypeCustom];
    [doneButton setTitle: NSLocalizedString(@"done_button_title", nil) forState: UIControlStateNormal];
    [doneButton sizeToFit];
    frame = doneButton.frame;
    frame.origin.x = kHXOCellPadding;
    doneButton.frame = frame;
    [doneButton addTarget: self action: @selector(donePressed:) forControlEvents: UIControlEventTouchUpInside];
    [self.headerView addSubview: doneButton];
    
    UIButton * enterButton = [UIButton buttonWithType: UIButtonTypeCustom];
    enterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [enterButton setTitle: NSLocalizedString(@"enter_button_title", nil) forState: UIControlStateNormal];
    [enterButton sizeToFit];
    frame = enterButton.frame;
    frame.origin.x = self.view.bounds.size.width - (frame.size.width + kHXOCellPadding);
    enterButton.frame = frame;
    [enterButton addTarget: self action: @selector(enterPressed:) forControlEvents: UIControlEventTouchUpInside];
    [self.headerView addSubview: enterButton];

    CGFloat handleWidth = 60;
    self.drawerHandleView = [[UIView alloc] initWithFrame: CGRectMake(0.5 * (self.view.bounds.size.width - handleWidth), self.codeDrawerView.frame.origin.y + self.codeDrawerView.frame.size.height + headerHeight + kHXOGridSpacing, handleWidth, kHXOGridSpacing)];
    self.drawerHandleView.backgroundColor = [UIColor colorWithWhite: 1.0 alpha: 0.5];
    self.drawerHandleView.layer.cornerRadius = 0.5 * self.drawerHandleView.bounds.size.height;
    [self.drawerScrollView addSubview: self.drawerHandleView];


    self.statusText = [[HXOLabel alloc] initWithFrame: CGRectZero];
    self.statusText.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusText.autoresizingMask = UIViewAutoresizingNone;
    self.statusText.font = [HXOUI theme].smallTextFont;
    self.statusText.text = NSLocalizedString(@"invite_scanner_prompt", nil);
    self.statusText.textInsets = UIEdgeInsetsMake(0, kHXOGridSpacing, 0, kHXOGridSpacing);
    [self.statusText sizeToFit];
    self.statusText.textColor = [UIColor whiteColor];
    self.statusText.backgroundColor = self.headerView.backgroundColor;
    self.statusText.layer.cornerRadius = 0.5 * self.statusText.bounds.size.height;
    self.statusText.layer.masksToBounds = YES;
    [self.view addSubview: self.statusText];
    [self.view sendSubviewToBack: self.statusText];

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.statusText
                                                           attribute:NSLayoutAttributeCenterX
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeCenterX
                                                          multiplier:1.f constant:0.f]];

    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.statusText
                                                           attribute:NSLayoutAttributeBottom
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeBottom
                                                          multiplier:1.f constant: -50.f]];
}

- (void) dealloc {
    self.drawerScrollView.delegate = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    self.codes = nil;
}

- (void) viewWillAppear: (BOOL) animated {
    [super viewWillAppear: animated];

    [self setupCaptureSession];

    self.drawerScrollView.layer.masksToBounds = YES;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    self.drawerScrollView.layer.masksToBounds = NO;
}

- (void) viewWillDisappear: (BOOL) animated {
    [super viewWillDisappear: animated];
    self.drawerScrollView.layer.masksToBounds = YES;
}

- (void) viewDidDisappear: (BOOL) animated {
    [super viewDidDisappear: animated];
    [self tearDownCaptureSession];
    [self clearCodeView];
}

- (BOOL) shouldAutorotate {
    return NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Video Capture and (QR) Codes

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
        AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;

        if ( ! self.codes[readableObject.stringValue]) {
            NSURL * url = [NSURL URLWithString: readableObject.stringValue];
            if ([url.scheme isEqualToString: @"hxo"]) {
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
                    alert.cancelButtonIndex = [alert addButtonWithTitle: NSLocalizedString(@"Cancel", nil)];
                    [alert addButtonWithTitle: NSLocalizedString(@"Open", nil)];
                } else {
                    alert.cancelButtonIndex = [alert addButtonWithTitle: NSLocalizedString(@"ok_button_title", nil)];
                }
                [alert show];
            }
            self.codes[readableObject.stringValue] = readableObject;
        }
    }
    self.codesInView = metadataObjects;
}

#pragma mark - UI Actions

- (void) donePressed: (id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) enterPressed: (id) sender {
    [HXOUI enterStringAlert: nil withTitle: NSLocalizedString(@"invite_code_enter_dialog_title", nil) withPlaceHolder: NSLocalizedString(@"invite_code_enter_placeholder", nil) onCompletion:^(NSString *entry) {
        if (entry) {
            [self.chatBackend pairByToken: entry];
        }
    }];
}

- (void) codeLabelTapped: (UIGestureRecognizer*) recognizer {
    [self.codeLabel becomeFirstResponder];
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    [menuController setTargetRect: self.codeLabel.bounds inView: self.codeLabel];
    [menuController setMenuVisible:YES animated:YES];
}

- (BOOL) canBecomeFirstResponder {
    return YES;
}

#pragma mark - Code Drawer View

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pagingPosition = scrollView.contentOffset.y / scrollView.bounds.size.height;
    CGRect frame = self.drawerHandleView.frame;
    frame.origin.y = [self handlePosition: pagingPosition];
    self.drawerHandleView.frame = frame;
    CGFloat white, alpha;
    [self.drawerHandleView.backgroundColor getWhite: &white alpha: &alpha];
    self.drawerHandleView.backgroundColor = [UIColor colorWithWhite: pagingPosition alpha: alpha];
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (fabs(scrollView.contentOffset.y) < 0.00001) {
        if ( ! self.isDrawerExtended) {
            [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
                if (token == nil || ! [token isKindOfClass:[NSString class]]) {
                    self.codeDrawerTitle.text = NSLocalizedString(@"invite_code_fetch_failed", nil);
                    return;
                }
                self.codeLabel.text = token;
                NSString * hxoURL = [NSString stringWithFormat: @"hxo://%@", token];
                DataMatrix * qrMatrix = [QREncoder encodeWithECLevel: QR_ECLEVEL_AUTO version: QR_VERSION_AUTO string: hxoURL];
                [UIView transitionWithView: self.qrCodeView
                                  duration: 0.3f
                                   options: UIViewAnimationOptionTransitionCrossDissolve
                                animations: ^{
                                    self.qrCodeView.image = [QREncoder renderTransparentDataMatrix: qrMatrix imageDimension: self.qrCodeView.bounds.size.width];
                                } completion:nil];
            }];
        }
        self.isDrawerExtended = YES;
    } else {
        [self clearCodeView];
        self.isDrawerExtended = NO;
    }
}

- (void) clearCodeView {
    self.codeLabel.text = nil;
    self.qrCodeView.image = nil;
    self.codeDrawerTitle.text = NSLocalizedString(@"invite_code_sheet_title", nil);
    self.drawerScrollView.contentOffset = CGPointMake(0, self.drawerScrollView.bounds.size.height);
}

- (CGFloat) handlePosition: (CGFloat) t {
    CGFloat drawerBottom = self.codeDrawerView.frame.origin.y + self.codeDrawerView.frame.size.height;
    CGFloat min = drawerBottom - (self.drawerHandleView.bounds.size.height + kHXOGridSpacing);
    CGFloat max = drawerBottom + self.headerView.bounds.size.height + kHXOGridSpacing;
    return min + t * (max - min);
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

@implementation PullUpView

- (UIView*) hitTest: (CGPoint) point withEvent: (UIEvent*) event {
    if (point.y > self.bounds.size.height + 80) { // XXX
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

@end
