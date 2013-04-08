//
//  AttachmentPickerController.h
//  HoccerTalk
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@class Attachment;

typedef enum AttachmentPickerTypes {
    AttachmentPickerTypePhotoFromLibrary,
    AttachmentPickerTypePhotoVideoFromLibrary,
    AttachmentPickerTypePhotoFromCamera,
    AttachmentPickerTypePhotoVideoFromCamera,
    AttachmentPickerTypeMediaFromLibrary
    //    AttachmentTypeContact
    // TODO: add more attachment types
} AttachmentPickerType;

@protocol AttachmentPickerControllerDelegate <NSObject>
- (void) didPickAttachment: (id) attachmentInfo;

@optional

- (BOOL) wantsAttachmentsOfType: (AttachmentPickerType) type;
- (NSString*) attachmentPickerActionSheetTitle;
- (BOOL) allowsEditing;

@end

@interface AttachmentPickerController : NSObject <UIActionSheetDelegate, UIImagePickerControllerDelegate, MPMediaPickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) id<AttachmentPickerControllerDelegate> delegate;

- (id) initWithViewController: (UIViewController*) viewController delegate: (id<AttachmentPickerControllerDelegate>) delegate;
- (void) showInView: (UIView*) view;

@end
