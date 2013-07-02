//
//  AttachmentPickerController.h
//  HoccerXO
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AddressBookUI/AddressBookUI.h>

#import "RecordViewController.h"
#import "GeoLocationPicker.h"
#import "HXOActionSheet.h"

@class Attachment;
@class RecordViewController;

typedef enum AttachmentPickerTypes {
    AttachmentPickerTypePhotoFromLibrary,
    AttachmentPickerTypePhotoVideoFromLibrary,
    AttachmentPickerTypePhotoFromCamera,
    AttachmentPickerTypePhotoVideoFromCamera,
    AttachmentPickerTypeMediaFromLibrary,
    AttachmentPickerTypeImageAttachmentFromPasteboard,
    AttachmentPickerTypeVideoAttachmentFromPasteboard,
    AttachmentPickerTypeAudioAttachmentFromPasteboard,
    AttachmentPickerTypeVcardAttachmentFromPasteboard,
    AttachmentPickerTypeGeoLocationAttachmentFromPasteboard,
    AttachmentPickerTypeImageFromPasteboard,
    AttachmentPickerTypeAudioRecorder,
    AttachmentPickerTypeAdressBookVcard,
    AttachmentPickerTypeGeoLocation
} AttachmentPickerType;

@protocol AttachmentPickerControllerDelegate <NSObject>
- (void) didPickAttachment: (id) attachmentInfo;

@optional

- (BOOL) wantsAttachmentsOfType: (AttachmentPickerType) type;
- (NSString*) attachmentPickerActionSheetTitle;
- (BOOL) allowsEditing;
- (void) prependAdditionalActionButtons: (ActionSheet*) actionSheet;
- (void) appendAdditionalActionButtons: (ActionSheet*) actionSheet;
- (void) additionalButtonPressed: (NSUInteger) buttonIndex;
- (BOOL) shouldSaveImagesToAlbum;
- (BOOL) shouldSaveVideosToAlbum;

@end

@interface AttachmentPickerController : NSObject <ActionSheetDelegate, UIImagePickerControllerDelegate, MPMediaPickerControllerDelegate, UINavigationControllerDelegate, AudioRecorderDelegate,ABPeoplePickerNavigationControllerDelegate,GeoLocationPickerDelegate>

@property (nonatomic, weak) id<AttachmentPickerControllerDelegate> delegate;

- (id) initWithViewController: (UIViewController*) viewController delegate: (id<AttachmentPickerControllerDelegate>) delegate;
- (void) showInView: (UIView*) view;

@property (readonly, strong, nonatomic) RecordViewController * recordViewController;
@property (readonly, nonatomic) GeoLocationPicker * geoLocationViewController;

@end
