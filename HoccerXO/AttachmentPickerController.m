//
//  AttachmentPickerController.m
//  HoccerXO
//
//  Created by David Siegel on 15.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentPickerController.h"
#import "RecordViewController.h"
#import "ABPersonVCardCreator.h"
#import "HXOUserDefaults.h"

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

@synthesize recordViewController = _recordViewController;

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

- (RecordViewController*) recordViewController {
    if (_recordViewController == nil) {
        _recordViewController = [_viewController.storyboard instantiateViewControllerWithIdentifier:@"RecordViewController"];
    }
    return _recordViewController;
}

- (void) probeAttachmentTypes {

    UIPasteboard * board = [UIPasteboard generalPasteboard];

#if 0
    // debug/reverse eng.: print content of pasteboard
    NSArray * items = board.items;
    for (NSDictionary * d in items) {
        NSLog(@"pasteboard contains item:");
        for (NSString * key in d) {
            NSLog(@"key/type: %@, value class: %@, value: %@", key, [d[key] class], d[key]);
        }
    }
#endif

    
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
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioRecorder]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"Record Audio", @"Action Sheet Button Ttitle");
        item.type = AttachmentPickerTypeAudioRecorder;
        [_supportedItems addObject: item];
    }
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeAdressBookVcard]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"Choose Adressbook Item", @"Action Sheet Button Ttitle");
        item.type = AttachmentPickerTypeAdressBookVcard;
        [_supportedItems addObject: item];
    }

    NSArray * myMediaTypeArray = [board valuesForPasteboardType:@"com.hoccer.xo.mediaType" inItemSet:nil];
    if (myMediaTypeArray.count == 1) {
        NSString * mediaType = [[NSString alloc] initWithData:myMediaTypeArray[0] encoding:NSUTF8StringEncoding];
        if ([mediaType isEqualToString:@"image"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeImageAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Image Attachment", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypeImageAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"video"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeVideoAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Video Attachment", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypeVideoAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"audio"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Audio Attachment", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypeAudioAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"vcard"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste vcard Attachment", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypeVcardAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
    }
    //if ([board containsPasteboardTypes:UIPasteboardTypeListImage inItemSet:nil]) {
    if (board.image != nil) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeImageFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Image", @"Action Sheet Button Ttitle");
            item.type = AttachmentPickerTypeImageFromPasteboard;
            [_supportedItems addObject: item];
        }
    }

    NSArray * myVideoTypeArray = [board valuesForPasteboardType:@"com.apple.mobileslideshow.asset-object-id-uri" inItemSet:nil];
    if (myVideoTypeArray.count == 1) {
        //NSString * myURL = [[NSString alloc] initWithData:myVideoTypeArray[0] encoding:NSUTF8StringEncoding];
        // NSLog(@"Video uri=%@", myURL);
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
        case AttachmentPickerTypeImageAttachmentFromPasteboard:
        case AttachmentPickerTypeVideoAttachmentFromPasteboard:
        case AttachmentPickerTypeAudioAttachmentFromPasteboard:
        case AttachmentPickerTypeVcardAttachmentFromPasteboard:
            [self pickAttachmentFromPasteBoard];
            break;
        case AttachmentPickerTypeImageFromPasteboard:
            [self pickImageFromPasteBoard];
            break;
        case AttachmentPickerTypeAudioRecorder:
            [self pickAudioFromRecorder];
            break;
        case AttachmentPickerTypeAdressBookVcard:
            [self pickVCardFromAdressbook];
            break;
    }
}

- (void) copyCustomStringFromPasteBoard:(NSString*)theType toDict:(NSMutableDictionary*) theDict optional:(BOOL)optional{
    UIPasteboard * board = [UIPasteboard generalPasteboard];
    NSArray * myTypeArray = [board valuesForPasteboardType:theType inItemSet:nil];
    if (myTypeArray.count == 1) {
        theDict[theType] = [[NSString alloc] initWithData:myTypeArray[0] encoding:NSUTF8StringEncoding];
    } else {
        if (!optional) {
            NSLog(@"ERROR: copyCustomStringFromPasteBoard: non-optional attachment info type not found: %@", theType);
        }
    }
}

- (void) pickAttachmentFromPasteBoard {
    NSMutableDictionary *myAttachmentInfo = [[NSMutableDictionary alloc] init];
    [self copyCustomStringFromPasteBoard:@"com.hoccer.xo.mediaType" toDict:myAttachmentInfo optional:NO];
    [self copyCustomStringFromPasteBoard:@"com.hoccer.xo.mimeType"  toDict:myAttachmentInfo optional:NO];
    [self copyCustomStringFromPasteBoard:@"com.hoccer.xo.fileName"  toDict:myAttachmentInfo optional:YES];
    [self copyCustomStringFromPasteBoard:@"com.hoccer.xo.url1"  toDict:myAttachmentInfo optional:NO];
    [self copyCustomStringFromPasteBoard:@"com.hoccer.xo.url2"  toDict:myAttachmentInfo optional:YES];
    [self.delegate didPickAttachment: myAttachmentInfo];
}

- (void) pickImageFromPasteBoard {
    UIPasteboard * board = [UIPasteboard generalPasteboard];
    /*
    id myImageObject = board.image;
    UIImage * myImage;
    if ([myImageObject isKindOfClass: [NSData class]]) {
        myImage = [UIImage imageWithData:myImageObject];
    } else if ([myImageObject isKindOfClass: [UIImage class]]) {
        myImage = (UIImage*) myImageObject;
    }
    */
    UIImage * myImage = board.image;
    if (myImage != nil) {
        NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.pastedImage": myImage};
        [self.delegate didPickAttachment: myAttachmentInfo];
    } else {
        NSLog(@"ERROR: pickImageFromPasteBoard: image is nil");
    }
}

- (void) pickAudioFromRecorder {
    self.recordViewController.delegate = self;
    [_viewController presentViewController: self.recordViewController animated: YES completion: nil];
}

- (void)audiorecorder:(RecordViewController *)audioRecorder didRecordAudio:(NSURL *)audioFileURL {
    NSLog(@"audiorecorder didRecordAudio %@",audioFileURL);
    NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.mediaType": @"audio",
                                       @"com.hoccer.xo.mimeType": @"audio/mp4",
                                       @"com.hoccer.xo.fileName": [audioFileURL lastPathComponent],
                                       @"com.hoccer.xo.url1": [audioFileURL absoluteString]};
    [self.delegate didPickAttachment: myAttachmentInfo];
}

- (void) pickVCardFromAdressbook {
    ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
    peoplePicker.peoplePickerDelegate = self;
    [_viewController presentViewController:peoplePicker animated:YES completion:nil];
}
#pragma mark -
#pragma mark ABPeoplePickerNavigationController delegate

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	
        CFErrorRef myError;
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &myError);
        ABRecordID contactId = ABRecordGetRecordID(person);
        ABRecordRef fullPersonInfo = ABAddressBookGetPersonWithRecordID(addressBook, contactId);
        if (fullPersonInfo != NULL){
            ABPersonVCardCreator * abPersonVCardCreator = [[ABPersonVCardCreator alloc] initWithPerson:fullPersonInfo];
            NSData * vcardData = [abPersonVCardCreator vcard];
            NSString * personName = [abPersonVCardCreator previewName];

            NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.vcard.data":vcardData,
                                               @"com.hoccer.xo.vcard.name":personName,
                                               @"com.hoccer.xo.vcard.recordid":@(contactId)};

            [self.delegate didPickAttachment: myAttachmentInfo];
            [peoplePicker dismissViewControllerAnimated:YES completion:nil];
        }
        CFRelease(addressBook);
        
    return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson:(ABRecordRef)person
								property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	return NO;
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark image/video picking


- (void) showImagePickerWithSource: (UIImagePickerControllerSourceType) sourceType withVideo: (BOOL) videoFlag {
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    if ([self.delegate respondsToSelector:@selector(allowsEditing)]) {
        picker.allowsEditing = [self.delegate allowsEditing];
    }
    NSInteger videoQuality = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"videoQuality"] integerValue];

    if (sourceType == UIImagePickerControllerSourceTypeCamera){
        if (videoFlag) {
            picker.mediaTypes =[UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
            picker.videoQuality = videoQuality;
        } else {
            picker.mediaTypes = @[(id)kUTTypeImage];
        }
    } else {
        if (videoFlag) {
            picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
            picker.videoQuality = videoQuality;
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
        // NSLog(@"mediaPicker Picked mediaItemCollection %@", mediaItemCollection);
        
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