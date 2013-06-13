//
//  InviteCodeViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InviteCodeViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "AppDelegate.h"
#import "HXOBackend.h"
#import "QREncoder.h"

@implementation InviteCodeViewController

@dynamic navigationItem;

@synthesize chatBackend = _chatBackend;

- (void) viewDidLoad {
    [super viewDidLoad];

    self.title = NSLocalizedString(@"invite_code_view_controller_title", nil);

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(canceld:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(onDone:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    self.codeTextField.delegate = self;
    self.codeTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeTextField.placeholder = NSLocalizedString(@"invite_code_field_placeholder", nil);

    /*
    UIImage * background = [[UIImage imageNamed: @"navbar-btn-blue"] stretchableImageWithLeftCapWidth: 4 topCapHeight: 0];
    self.getNewCodeButton.backgroundColor = [UIColor clearColor];
    [self.getNewCodeButton setBackgroundImage: background forState: UIControlStateNormal];
    [self.getNewCodeButton setTitle: NSLocalizedString(@"invite_get_new_code_button", nil) forState:UIControlStateNormal];
*/
    self.qrCodeView.hidden = YES;
    self.qrCodeReaderView.readerDelegate = self;
    self.qrCodeReaderView.layer.borderColor = [UIColor blackColor].CGColor;
    self.qrCodeReaderView.layer.borderWidth = 1;

    _scannedCodes = [[NSMutableSet alloc] init];

#if TARGET_IPHONE_SIMULATOR
    _qrCameraSimulator = [[ZBarCameraSimulator alloc] initWithViewController: self];
    _qrCameraSimulator.readerView = self.qrCodeReaderView;
#endif

    [HXOBackend registerConnectionInfoObserverFor:self];

}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    
    if (!self.presentCodeMode) {
        self.label.text = NSLocalizedString(@"Enter_an_invite_token_here", nil);
        self.qrLabel.text = NSLocalizedString(@"or_scan_an_invite_code", nil);
    } else {
        self.label.text = NSLocalizedString(@"Give_this_token_to_a_friend", nil);
        self.qrLabel.text = NSLocalizedString(@"let_a_friend_scan_this_code", nil);
        self.codeTextField.enabled = NO;
    }

    _newTokenButtonPressed = NO;

    self.qrCodeView.hidden = YES;
    self.qrCodeReaderView.hidden = NO;

    UIApplication *app = [UIApplication sharedApplication];
    [self.qrCodeReaderView willRotateToInterfaceOrientation: app.statusBarOrientation
                                        duration: 0];
    [HXOBackend broadcastConnectionInfo];
    if (self.presentCodeMode) {
        [self getNewCode];
    }
}

- (void) viewDidAppear: (BOOL) animated {
    if (!self.presentCodeMode) {
        [self.qrCodeReaderView start];
    }
}

- (void) viewWillDisappear: (BOOL) animated {
    if (!self.presentCodeMode) {
        [self.qrCodeReaderView stop];
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
    [self onDone: nil];
}

- (IBAction) newCodePressed:(id)sender {
    [self getNewCode];
}

- (void) getNewCode {
    _newTokenButtonPressed = YES;
    self.navigationItem.leftBarButtonItem = nil;
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        if (![token isKindOfClass:[NSString class]]) {
            self.codeTextField.text = @"<ERROR>";
            return;
        }
        self.label.text = NSLocalizedString(@"Give_this_token_to_a_friend", nil);
        self.qrLabel.text = NSLocalizedString(@"let_a_friend_scan_this_code", nil);
        
        self.codeTextField.text = token;
        
        [self.qrCodeReaderView stop];
        self.qrCodeReaderView.hidden = YES;
        self.qrCodeView.hidden = NO;
        [self renderQRCode: token];
    }];
}

- (void) onDone:(id) sender {
    if ( ! _newTokenButtonPressed && ! [self.codeTextField.text isEqualToString: @""]) {
        [self.chatBackend pairByToken: self.codeTextField.text];
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) canceld:(id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

#pragma mark - QR Code Handling

- (void) renderQRCode: (NSString*) token {
    NSString * hxoURL = [NSString stringWithFormat: @"hxo://%@", token];
    DataMatrix * qrMatrix = [QREncoder encodeWithECLevel: QR_ECLEVEL_AUTO version: QR_VERSION_AUTO string: hxoURL];
    self.qrCodeView.image = [QREncoder renderTransparentDataMatrix: qrMatrix imageDimension: self.qrCodeView.bounds.size.width];
}

- (BOOL) shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation) orient
{
    // auto-rotation is supported
    return(YES);
}

- (void) willRotateToInterfaceOrientation: (UIInterfaceOrientation) orient
                                 duration: (NSTimeInterval) duration
{
    // compensate for view rotation so camera preview is not rotated
    [self.qrCodeReaderView willRotateToInterfaceOrientation: orient
                                        duration: duration];
}

- (void) willAnimateRotationToInterfaceOrientation: (UIInterfaceOrientation) orient
                                          duration: (NSTimeInterval) duration
{
    // perform rotation in animation loop so camera preview does not move
    // wrt device orientation
    [self.qrCodeReaderView setNeedsLayout];
}

- (void) readerView: (ZBarReaderView*) view didReadSymbols: (ZBarSymbolSet*) symbols fromImage: (UIImage*) image {
    for(ZBarSymbol *symbol in symbols) {
        [self processScannedSymbol: symbol];
    }
}

- (void) processScannedSymbol: (ZBarSymbol*) symbol {
    if ([_scannedCodes containsObject: symbol.data]) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"invite_qr_code_already_scanned_title", nil)
                                                         message:NSLocalizedString(@"invite_qr_code_already_scanned_message", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                               otherButtonTitles: nil];
        [alert show];

    } else {
        [_scannedCodes addObject: symbol.data];
        NSURL * url = [NSURL URLWithString: symbol.data];
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
}

@end
