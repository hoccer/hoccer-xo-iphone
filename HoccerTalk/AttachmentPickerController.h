//
//  AttachmentPickerController.h
//  HoccerTalk
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;

@protocol AttachmentPcikerControllerDelegate
- (void) didPickAttachment: (id) attachmentInfo;
@end

@interface AttachmentPickerController : NSObject <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) id<AttachmentPcikerControllerDelegate> delegate;

- (id) initWithViewController: (UIViewController*) viewController delegate: (id<AttachmentPcikerControllerDelegate>) delegate;
- (void) showInView: (UIView*) view;

@end
