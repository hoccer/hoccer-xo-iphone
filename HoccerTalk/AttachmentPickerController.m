//
//  AttachmentPickerController.m
//  HoccerTalk
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentPickerController.h"

typedef enum AttachmentTypes {
    AttachmentTypePhotoFromLibrary,
    AttachmentTypePhotoFromCamera,
//    AttachmentTypeContact
// TODO: add more attachment types
} AttachmentType;

@interface AttachmentPickerController ()
{
    NSMutableArray * _supportedItems;
    UIViewController * _viewController;
}
@end

@interface AttachmentPickerItem : NSObject
@property (nonatomic,strong) NSString* localizedButtonTitle;
@property (nonatomic, assign) AttachmentType type;
@end

@implementation AttachmentPickerController

- (id) initWithViewController: (UIViewController*) viewController delegate:(id<AttachmentPickerControllerDelegate>)delegate {
    self = [super init];
    if (self != nil) {
        self.delegate = delegate;
        _viewController = viewController;
        _supportedItems = [[NSMutableArray alloc] init];
        [self probeAttachmentTypes];
    }
    return self;
}

- (void) probeAttachmentTypes {
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"Choose Photo/Video", @"Action Sheet Button Ttitle");
        item.type = AttachmentTypePhotoFromLibrary;
        [_supportedItems addObject: item];
    }
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        // TODO: test for video support
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"Take Photo/Video", @"Action Sheet Button Ttitle");
        item.type = AttachmentTypePhotoFromCamera;
        [_supportedItems addObject: item];
    }
    // TODO: add other types
}

- (void) showInView: (UIView*) view {
    UIActionSheet *attachmentSheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"Add Attachement", @"Attachment Actionsheet Title")
                                                                 delegate: self
                                                        cancelButtonTitle: nil
                                                   destructiveButtonTitle: nil
                                                        otherButtonTitles: nil];
    attachmentSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;


    for (AttachmentPickerItem * item in _supportedItems) {
        [attachmentSheet addButtonWithTitle: item.localizedButtonTitle];
    }
    attachmentSheet.cancelButtonIndex = [attachmentSheet addButtonWithTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")];
    
    [attachmentSheet showInView: view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self.delegate didPickAttachment: nil];
        return;
    }
    AttachmentPickerItem * item = _supportedItems[buttonIndex];
    [self showPickerForType: item.type];
}

- (void) showPickerForType: (AttachmentType) type {
    switch (type) {
        case AttachmentTypePhotoFromLibrary:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypePhotoLibrary];
            break;
        case AttachmentTypePhotoFromCamera:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypeCamera];
            break;
    }
}

- (void) showImagePickerWithSource: (UIImagePickerControllerSourceType) sourceType {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    if (sourceType == UIImagePickerControllerSourceTypeCamera){
        picker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
        picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    }
    else {
        picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
    }
    [_viewController presentViewController: picker animated: YES completion: nil];

}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [_viewController dismissViewControllerAnimated: YES completion: nil];
    [self.delegate didPickAttachment: info];
}

@end

@implementation AttachmentPickerItem
@end