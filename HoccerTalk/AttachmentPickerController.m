//
//  AttachmentPickerController.m
//  HoccerTalk
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentPickerController.h"

#import <MediaPlayer/MPMediaItemCollection.h>
#import <MobileCoreServices/UTCoreTypes.h>

@interface AttachmentPickerController ()
{
    NSMutableArray * _supportedItems;
    UIViewController * _viewController;
    NSUInteger _firstPickerButton;
}
@end

@interface AttachmentPickerItem : NSObject
@property (nonatomic,strong) NSString* localizedButtonTitle;
@property (nonatomic, assign) AttachmentPickerType type;
@end

@implementation AttachmentPickerController

- (id) initWithViewController: (UIViewController*) viewController delegate:(id<AttachmentPickerControllerDelegate>)delegate {
    self = [super init];
    if (self != nil) {
        self.delegate = delegate;
        _viewController = viewController;
        _supportedItems = [[NSMutableArray alloc] init];
        _firstPickerButton = 0;
        [self probeAttachmentTypes];
    }
    return self;
}

- (void) probeAttachmentTypes {
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoVideoFromLibrary]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Choose Photo/Video", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypePhotoVideoFromLibrary;
            [_supportedItems addObject: item];
        } else if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoFromLibrary]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Choose Photo", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypePhotoFromLibrary;
            [_supportedItems addObject: item];
        }
    }
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoVideoFromCamera]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Take Photo/Video", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypePhotoVideoFromCamera;
            [_supportedItems addObject: item];
        } else if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoFromCamera]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Take Photo", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypePhotoFromCamera;
            [_supportedItems addObject: item];
        }
    }
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeMediaFromLibrary]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"Choose Audio", @"Action Sheet Button Ttitle");
        item.type = AttachmentPickerTypeMediaFromLibrary;
        [_supportedItems addObject: item];        
    }
    // TODO: add other types
}

- (BOOL) delegateWantsAttachmentsOfType: (AttachmentPickerType) type {
    if ([self.delegate respondsToSelector:@selector(wantsAttachmentsOfType:)]) {
        return [self.delegate wantsAttachmentsOfType: type];
    }
    return YES;
}

- (void) showInView: (UIView*) view {
    NSString * title;
    if ([self.delegate respondsToSelector:@selector(attachmentPickerActionSheetTitle)]) {
        title = [self.delegate attachmentPickerActionSheetTitle];
    } else {
        title = NSLocalizedString(@"Add Attachement", @"Attachment Actionsheet Title");
    }
    UIActionSheet *attachmentSheet = [[UIActionSheet alloc] initWithTitle: title
                                                                 delegate: self
                                                        cancelButtonTitle: nil
                                                   destructiveButtonTitle: nil
                                                        otherButtonTitles: nil];
    attachmentSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;

    if ([self.delegate respondsToSelector:@selector(prependAdditionalActionButtons:)]) {
        [self.delegate prependAdditionalActionButtons: attachmentSheet];
    }
    _firstPickerButton = attachmentSheet.numberOfButtons;
    for (AttachmentPickerItem * item in _supportedItems) {
        [attachmentSheet addButtonWithTitle: item.localizedButtonTitle];
    }
    if ([self.delegate respondsToSelector:@selector(appendAdditionalActionButtons:)]) {
        [self.delegate appendAdditionalActionButtons: attachmentSheet];
    }
    attachmentSheet.cancelButtonIndex = [attachmentSheet addButtonWithTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")];
    
    [attachmentSheet showInView: view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self.delegate didPickAttachment: nil];
        return;
    }
    if (buttonIndex >= _firstPickerButton && buttonIndex < _firstPickerButton + _supportedItems.count) {
        AttachmentPickerItem * item = _supportedItems[buttonIndex - _firstPickerButton];
        [self showPickerForType: item.type];
    } else if ([self.delegate respondsToSelector:@selector(additionalButtonPressed:)]) {
        [self.delegate additionalButtonPressed: buttonIndex];
    }
}

- (void) showPickerForType: (AttachmentPickerType) type {
    BOOL wantsVideo = YES;
    switch (type) {
        case AttachmentPickerTypePhotoFromLibrary:
            wantsVideo = NO;
            // no break
        case AttachmentPickerTypePhotoVideoFromLibrary:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypePhotoLibrary withVideo: wantsVideo];
            break;
        case AttachmentPickerTypePhotoFromCamera:
            wantsVideo = NO;
            // no break
        case AttachmentPickerTypePhotoVideoFromCamera:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypeCamera withVideo: wantsVideo];
            break;
        case AttachmentPickerTypeMediaFromLibrary:
            [self showMediaPicker];
            break;
    }
}

- (void) showImagePickerWithSource: (UIImagePickerControllerSourceType) sourceType withVideo: (BOOL) videoFlag {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    if ([self.delegate respondsToSelector:@selector(allowsEditing)]) {
        picker.allowsEditing = [self.delegate allowsEditing];
    }
    if (sourceType == UIImagePickerControllerSourceTypeCamera){
        if (videoFlag) {
            picker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
            picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
        } else {
            picker.mediaTypes = @[(id)kUTTypeImage];
        }
    } else {
        if (videoFlag) {
            picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
        } else {
            picker.mediaTypes = @[(id)kUTTypeImage];
        }
    }
    [_viewController presentViewController: picker animated: YES completion: nil];

}

- (void) showMediaPicker {
    
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny];
    
    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = NO;
    mediaPicker.prompt = nil;

    [_viewController presentViewController:mediaPicker animated:YES completion: nil];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [mediaPicker dismissViewControllerAnimated: YES completion: nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    
    if (mediaItemCollection) {
        NSLog(@"mediaPicker Picked mediaItemCollection %@", mediaItemCollection);
        
        MPMediaItem * mediaItem = [[mediaItemCollection items ]objectAtIndex:0];
        [self.delegate didPickAttachment: mediaItem];
                
    }
    [mediaPicker dismissViewControllerAnimated: YES completion: nil];
}


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [_viewController dismissViewControllerAnimated: YES completion: nil];
    [self.delegate didPickAttachment: info];
}

@end

@implementation AttachmentPickerItem
@end