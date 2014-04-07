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
@property (nonatomic, strong)   CALayer                    * codeOutlineLayer;

@property (nonatomic, readonly) HXOBackend                 * chatBackend;

@end

@interface PullUpView : UIScrollView

@end

@implementation InvitationCodeViewController

@synthesize chatBackend = _chatBackend;

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor lightGrayColor];

    self.codeOutlineLayer = [CALayer layer];
    self.codeOutlineLayer.frame = self.view.layer.bounds;
    self.codeOutlineLayer.delegate = self;
    [self.view.layer addSublayer: self.codeOutlineLayer];

    CGFloat headerHeight = 4 * kHXOGridSpacing;
    self.headerView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, headerHeight)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerView.backgroundColor = [UIColor colorWithWhite: 0 alpha: 0.3];
    [self.view addSubview: self.headerView];

    CGFloat contentWidth = self.view.bounds.size.width - 2 * kHXOCellPadding;
    self.codeDrawerTitle = [[UILabel alloc] initWithFrame: CGRectZero];
    self.codeDrawerTitle.text = NSLocalizedString(@"Invite Code", nil);
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
    [doneButton setTitle: NSLocalizedString(@"Done", nil) forState: UIControlStateNormal];
    [doneButton sizeToFit];
    frame = doneButton.frame;
    frame.origin.x = kHXOCellPadding;
    doneButton.frame = frame;
    [doneButton addTarget: self action: @selector(donePressed:) forControlEvents: UIControlEventTouchUpInside];
    [self.headerView addSubview: doneButton];
    
    UIButton * enterButton = [UIButton buttonWithType: UIButtonTypeCustom];
    enterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [enterButton setTitle: NSLocalizedString(@"Enter", nil) forState: UIControlStateNormal];
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
}

- (void) dealloc {
    self.drawerScrollView.delegate = nil;
    self.codeOutlineLayer.delegate = nil;
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
    [self.captureSession removeInput: self.captureSession.inputs[0]];
    [self.captureSession removeOutput: self.captureSession.outputs[0]];
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
            } else {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"invite_not_a_hoccer_xo_qr_code_title", nil)
                                                                 message:NSLocalizedString(@"invite_not_a_hoccer_xo_qr_code_message", nil)
                                                                delegate: self
                                                       cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                                       otherButtonTitles: nil];
                [alert show];
            }
        }
        self.codes[readableObject.stringValue] = readableObject;
    }
    self.codesInView = metadataObjects;
    [self.codeOutlineLayer setNeedsDisplay];
}

#pragma mark - UI Actions

- (void) donePressed: (id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) enterPressed: (id) sender {
    [HXOUI enterStringAlert: nil withTitle: NSLocalizedString(@"Enter xo invite code", nil) withPlaceHolder: NSLocalizedString(@"Invite Code", nil) onCompletion:^(NSString *entry) {
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
        [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
            if (token == nil || ! [token isKindOfClass:[NSString class]]) {
                self.codeDrawerTitle.text = @"Failed to get token.";
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
    } else {
        [self clearCodeView];
    }
}

- (void) clearCodeView {
    self.codeLabel.text = nil;
    self.qrCodeView.image = nil;
    self.codeDrawerTitle.text = NSLocalizedString(@"Invite Code", nil);
    self.drawerScrollView.contentOffset = CGPointMake(0, self.drawerScrollView.bounds.size.height);
}

- (CGFloat) handlePosition: (CGFloat) t {
    CGFloat drawerBottom = self.codeDrawerView.frame.origin.y + self.codeDrawerView.frame.size.height;
    CGFloat min = drawerBottom - (self.drawerHandleView.bounds.size.height + kHXOGridSpacing);
    CGFloat max = drawerBottom + self.headerView.bounds.size.height + kHXOGridSpacing;
    return min + t * (max - min);
}

#pragma mark - Outline Rendering

- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if ([layer isEqual: self.codeOutlineLayer]) {
        for (AVMetadataMachineReadableCodeObject * code in self.codesInView) {
            CGRect bounds = [self.videoLayer rectForMetadataOutputRectOfInterest: code.bounds];
            CGColorRef color = [UIColor yellowColor].CGColor;
            CGContextSetStrokeColorWithColor(ctx, color);
            CGContextStrokeRect(ctx, bounds);
        }
    }
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
