//
//  InviteCodeViewController.h
//  HoccerXO
//
//  Created by David Siegel on 05.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZBarSDK.h"

@class HXOBackend;

static const NSTimeInterval kInvitationTokenValidity = 60 * 60 * 24 * 7; // one week


@interface InviteCodeViewController : UIViewController <UITextFieldDelegate, ZBarReaderViewDelegate>
{
    BOOL _newTokenButtonPressed;
    NSMutableSet * _scannedCodes;
#if TARGET_IPHONE_SIMULATOR
    ZBarCameraSimulator * _qrCameraSimulator;
#endif
}

@property (nonatomic) BOOL presentCodeMode;

@property (nonatomic, readonly) HXOBackend * chatBackend;
@property (strong, nonatomic) IBOutlet UILabel *label;
@property (strong, nonatomic) IBOutlet UITextField * codeTextField;
@property (strong, nonatomic) IBOutlet UINavigationItem *navigationItem;
// @property (strong, nonatomic) IBOutlet UIButton *getNewCodeButton;

@property (strong, nonatomic) IBOutlet UIImageView *qrCodeView;
@property (nonatomic, retain) IBOutlet ZBarReaderView *qrCodeReaderView;

@property (strong, nonatomic) IBOutlet UILabel *qrLabel;

@end
