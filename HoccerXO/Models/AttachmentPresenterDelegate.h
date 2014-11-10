//
//  AttachmentPresenterDelegate.h
//  HoccerXO
//
//  Created by pavel on 10/11/14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#ifndef HoccerXO_AttachmentPresenterDelegate_h
#define HoccerXO_AttachmentPresenterDelegate_h

#import "ImageViewController.h"

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MediaPlayer/MediaPlayer.h>

@class Attachment;

@protocol AttachmentPresenterDelegate<ABUnknownPersonViewControllerDelegate, UIDocumentInteractionControllerDelegate>

- (void) previewAttachment:(Attachment *)attachment;

@property (nonatomic, strong) UIDocumentInteractionController * interactionController;
@property (nonatomic, strong) MPMoviePlayerViewController     * moviePlayerViewController;
@property (nonatomic, readonly) ImageViewController             * imageViewController;
@property (nonatomic, readonly) ABUnknownPersonViewController   * vcardViewController;
@property (nonatomic, readonly) UIViewController                * thisViewController;

@end
#endif
