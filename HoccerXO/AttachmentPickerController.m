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
#import "HXOLocalization.h"
#import "TDSemiModal.h"
#import "GeoLocationPicker.h"
#import "AppDelegate.h"
#import "Attachment.h"

#import "UIAlertView+BlockExtensions.h"

#import <MediaPlayer/MPMediaItemCollection.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>

@interface AttachmentPickerController ()
{
    NSMutableArray * _supportedItems;
    UIViewController * _viewController;
    UIBackgroundTaskIdentifier _backgroundTask;
}

@property (nonatomic,readonly) UINavigationController * modalLocationPickerHelper;

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
        _supportedItems = [NSMutableArray array];
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


#if 0 // old single selection
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoVideoFromLibrary]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"attachment_src_photo_album_btn_title", nil);
            item.type = AttachmentPickerTypePhotoVideoFromLibrary;
            [_supportedItems addObject: item];
        } else if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoFromLibrary]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"attachment_src_photo_album_btn_title", nil);
            item.type = AttachmentPickerTypePhotoFromLibrary;
            [_supportedItems addObject: item];
        }
    }
#endif

    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary]) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoVideoFromLibrary] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoFromLibrary]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"attachment_src_media_btn_title", nil);
            item.type = AttachmentPickerTypeMulti;
            [_supportedItems addObject: item];
        }
    }

    
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoVideoFromCamera]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"attachment_src_camera_btn_title", nil);
            item.type = AttachmentPickerTypePhotoVideoFromCamera;
            [_supportedItems addObject: item];
        } else if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypePhotoFromCamera]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"attachment_src_camera_btn_title",nil);
            item.type = AttachmentPickerTypePhotoFromCamera;
            [_supportedItems addObject: item];
        }
    }
#ifndef HXO_UNDERGROUND_MUSIC
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeMediaFromLibrary]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"attachment_src_music_library_btn_title", nil);
        item.type = AttachmentPickerTypeMediaFromLibrary;
        [_supportedItems addObject: item];
    }
#endif
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioRecorder]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"attachment_src_recorder_btn_title", nil);
        item.type = AttachmentPickerTypeAudioRecorder;
        [_supportedItems addObject: item];
    }
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeAdressBookVcard]) {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"attachment_src_adressbook_btn_title", nil);
        item.type = AttachmentPickerTypeAdressBookVcard;
        [_supportedItems addObject: item];
    }
    if ([self delegateWantsAttachmentsOfType: AttachmentPickerTypeGeoLocation]/* &&
        [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied*/)
    {
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        item.localizedButtonTitle = NSLocalizedString(@"attachment_src_map_btn_title", nil);
        item.type = AttachmentPickerTypeGeoLocation;
        [_supportedItems addObject: item];
    }

    BOOL imageAttachmentinPasteboard = NO;
    NSArray * myMediaTypeArray = [board valuesForPasteboardType:@"com.hoccer.xo.mediaType" inItemSet:nil];
    if (myMediaTypeArray.count == 1) {
        NSString * mediaType = [[NSString alloc] initWithData:myMediaTypeArray[0] encoding:NSUTF8StringEncoding];
        if ([mediaType isEqualToString:@"image"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeImageAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Image Attachment", nil);
            item.type = AttachmentPickerTypeImageAttachmentFromPasteboard;
            [_supportedItems addObject: item];
            imageAttachmentinPasteboard = YES;
        }
        if ([mediaType isEqualToString:@"video"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeVideoAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Video Attachment", nil);
            item.type = AttachmentPickerTypeVideoAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"audio"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste Audio Attachment", nil);
            item.type = AttachmentPickerTypeAudioAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"vcard"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste vcard Attachment", nil);
            item.type = AttachmentPickerTypeVcardAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"geolocation"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            item.localizedButtonTitle = NSLocalizedString(@"Paste geolocation Attachment", nil);
            item.type = AttachmentPickerTypeGeoLocationAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
        if ([mediaType isEqualToString:@"data"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeDataAttachmentFromPasteboard]) {
            AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
            NSString * dataDescription = nil;
            NSArray * myMediaTypeArray = [board valuesForPasteboardType:@"com.hoccer.xo.mimeType" inItemSet:nil];
            if (myMediaTypeArray.count == 1) {
                NSString * mimeType = [[NSString alloc] initWithData:myMediaTypeArray[0] encoding:NSUTF8StringEncoding];
                dataDescription = [Attachment fileExtensionFromMimeType:mimeType];
                //dataDescription = [Attachment localizedDescriptionOfMimeType:mimeType];
            }
            if (dataDescription == nil) {
                dataDescription = NSLocalizedString(mediaType, "");
            }
            NSString * title = [NSString stringWithFormat:NSLocalizedString(@"Paste data Attachment %@",""),dataDescription];
            item.localizedButtonTitle = title;
            item.type = AttachmentPickerTypeDataAttachmentFromPasteboard;
            [_supportedItems addObject: item];
        }
    }
    //if ([board containsPasteboardTypes:UIPasteboardTypeListImage inItemSet:nil]) {
    if (board.image != nil && !imageAttachmentinPasteboard) {
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
    
    AppDelegate * myAppDelegate =  ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    if (myAppDelegate.openedFileURL != nil) {
        NSString * mediaType = myAppDelegate.openedFileMediaType;
        AttachmentPickerItem * item = [[AttachmentPickerItem alloc] init];
        BOOL match = NO;
        NSString * dataDescription = nil;

        if ([mediaType isEqualToString:@"image"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeImageAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeImageAttachmentFromOpenedFile;
            match = YES;
        }
        if ([mediaType isEqualToString:@"video"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeVideoAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeVideoAttachmentFromOpenedFile;
            match = YES;
        }
        if ([mediaType isEqualToString:@"audio"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeAudioAttachmentFromOpenedFile;
            match = YES;
        }
        if ([mediaType isEqualToString:@"vcard"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeVcardAttachmentFromOpenedFile;
            match = YES;
        }
        if ([mediaType isEqualToString:@"geolocation"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeAudioAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeGeoLocationAttachmentFromOpenedFile;
            match = YES;
        }
        if ([mediaType isEqualToString:@"data"] &&
            [self delegateWantsAttachmentsOfType: AttachmentPickerTypeDataAttachmentFromOpenedFile]) {
            item.type = AttachmentPickerTypeDataAttachmentFromOpenedFile;
            dataDescription = [Attachment fileExtensionFromMimeType:myAppDelegate.openedFileMimeType];
            //dataDescription = [Attachment localizedDescriptionOfUTI:myAppDelegate.openedFileDocumentType];
            match = YES;
        }
        if (match) {
            if (dataDescription == nil) {
                dataDescription = NSLocalizedString(mediaType, "");
            }
            NSString * title = [NSString stringWithFormat:NSLocalizedString(@"Opened data Attachment %@",""),dataDescription];
            item.localizedButtonTitle = title;
            NSLog(@"item.type=%d",item.type);
            [_supportedItems addObject: item];
        }
    }
}

- (BOOL) delegateWantsAttachmentsOfType: (AttachmentPickerType) type {
    return YES;
}

- (void) showInView: (UIView*) view {
    UIActionSheet *attachmentSheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"attachment_add_sheet_title", nil)
                                                                 delegate: self
                                                        cancelButtonTitle: nil
                                                   destructiveButtonTitle: nil
                                                        otherButtonTitles: nil];
    attachmentSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;

    for (AttachmentPickerItem * item in _supportedItems) {
        [attachmentSheet addButtonWithTitle: item.localizedButtonTitle];
    }
    attachmentSheet.cancelButtonIndex = [attachmentSheet addButtonWithTitle: NSLocalizedString(@"cancel", nil)];
    
    [attachmentSheet showInView: view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        [self.delegate didPickAttachment: nil];
    } else {
        AttachmentPickerItem * item = _supportedItems[buttonIndex];
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self showPickerForType: item.type];
        });
    }
}

- (void) requestCameraAccessForType: (AttachmentPickerType) type {
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // Will get here on both iOS 7 & 8 even though camera permissions weren't required
            // until iOS 8. So for iOS 7 permission will always be granted.
            if (granted) {
                // Permission has been granted. Use dispatch_async for any UI updating
                // code because this block may be executed in a thread.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showCameraPickerForType:type];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [AppDelegate.instance showGenericAlertWithTitle:@"permission_denied_title"
                                                         andMessage:HXOLocalizedString(@"permission_denied_camera_attachment", nil, HXOAppName())
                                                        withOKBlock:^{}];
                });
            }
        }];
    } else {
        // We are on iOS <= 6. Just do what we need to do.
        [self showCameraPickerForType:type];
    }
}

- (void) showCameraPickerForType: (AttachmentPickerType) type {
    BOOL wantsVideo = YES;
    switch (type) {
        case AttachmentPickerTypePhotoFromCamera:
            wantsVideo = NO;
            // no break
        case AttachmentPickerTypePhotoVideoFromCamera:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypeCamera withVideo: wantsVideo];
            break;
        default:
            NSLog(@"showCameraPickerForType: not a camera picker");
    }
}

- (void) showPickerForType: (AttachmentPickerType) type {
    BOOL wantsVideo = YES;
    // NSLog(@"showPickerForType=%d",type);
    switch (type) {
        case AttachmentPickerTypeMulti:
            [self pickMultipleImages: @[]];
            break;
        case AttachmentPickerTypePhotoFromLibrary:
            wantsVideo = NO;
            // no break
        case AttachmentPickerTypePhotoVideoFromLibrary:
            [self showImagePickerWithSource: UIImagePickerControllerSourceTypePhotoLibrary withVideo: wantsVideo];
            break;
        case AttachmentPickerTypePhotoFromCamera:
        case AttachmentPickerTypePhotoVideoFromCamera:
            [self requestCameraAccessForType:type];
            break;
        case AttachmentPickerTypeMediaFromLibrary:
            [self showMediaPicker];
            break;
        case AttachmentPickerTypeImageAttachmentFromPasteboard:
        case AttachmentPickerTypeVideoAttachmentFromPasteboard:
        case AttachmentPickerTypeAudioAttachmentFromPasteboard:
        case AttachmentPickerTypeVcardAttachmentFromPasteboard:
        case AttachmentPickerTypeGeoLocationAttachmentFromPasteboard:
        case AttachmentPickerTypeDataAttachmentFromPasteboard:
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
        case AttachmentPickerTypeGeoLocation:
            [self pickGeoLocation];
            break;
        case AttachmentPickerTypeImageAttachmentFromOpenedFile:
        case AttachmentPickerTypeVideoAttachmentFromOpenedFile:
        case AttachmentPickerTypeAudioAttachmentFromOpenedFile:
        case AttachmentPickerTypeVcardAttachmentFromOpenedFile:
        case AttachmentPickerTypeGeoLocationAttachmentFromOpenedFile:
        case AttachmentPickerTypeDataAttachmentFromOpenedFile:
            [self pickAttachmentFromOpenedFile];
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

- (void) pickAttachmentFromOpenedFile {
    AppDelegate * myAppDelegate =  ((AppDelegate*)[[UIApplication sharedApplication] delegate]);
    
    NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.mediaType" : myAppDelegate.openedFileMediaType,
                                              @"com.hoccer.xo.mimeType" : myAppDelegate.openedFileMimeType,
                                              @"com.hoccer.xo.fileName" : myAppDelegate.openedFileName,
                                              @"com.hoccer.xo.url1" : [myAppDelegate.openedFileURL absoluteString]
                                              };
    [self.delegate didPickAttachment: myAttachmentInfo];
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
    [_viewController presentSemiModalViewController:self.recordViewController
                                             inView: UIApplication.sharedApplication.delegate.window];
}

- (void)audiorecorder:(RecordViewController *)audioRecorder didRecordAudio:(NSURL *)audioFileURL {
    NSLog(@"audiorecorder didRecordAudio %@",audioFileURL);
    
    audioFileURL = [AppDelegate moveDocumentToPermanentLocation:audioFileURL];

    NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.mediaType": @"audio",
                                       @"com.hoccer.xo.mimeType": @"audio/mp4",
                                       @"com.hoccer.xo.fileName": [audioFileURL lastPathComponent],
                                       @"com.hoccer.xo.url1": [audioFileURL absoluteString]};
    [self.delegate didPickAttachment: myAttachmentInfo];
}

- (void) pickVCardFromAdressbook {
    CFErrorRef myError;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &myError);
    [self checkAddressBookAccessforBook:addressBook WithHandler:^(bool granted, CFErrorRef error) {
        if (granted) {
            ABPeoplePickerNavigationController *peoplePicker = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).peoplePicker;
            peoplePicker.peoplePickerDelegate = self;
            [_viewController presentViewController:peoplePicker animated:YES completion:nil];
            [AppDelegate setBlackFontStatusbarForViewController:_viewController];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"permission_denied_title", "") message:HXOLocalizedString(@"permission_denied_addressbook_message", nil, HXOAppName()) delegate:nil cancelButtonTitle:NSLocalizedString(@"ok","") otherButtonTitles:nil];
            [alert show];
        }
    }];
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

// new in iOS8
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
                         didSelectPerson:(ABRecordRef)person {
    
    [self peoplePickerNavigationController:peoplePicker shouldContinueAfterSelectingPerson:person];
}

#pragma mark Address Book Access

-(void)checkAddressBookAccessforBook:(ABAddressBookRef)book WithHandler:(ABAddressBookRequestAccessCompletionHandler)handler
{
    switch (ABAddressBookGetAuthorizationStatus())
    {
        case kABAuthorizationStatusAuthorized:
            handler(YES, nil);
            break;
        case kABAuthorizationStatusNotDetermined :
        {
            ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
                // callback will come on any queue, so force handler call on main queue
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(granted, error);
                });
            });
        }
            break;
        case kABAuthorizationStatusDenied:
        case kABAuthorizationStatusRestricted:
        {
            handler(NO, nil);
        }
            break;
        default:
            NSLog(@"#ERROR: ABAddressBookGetAuthorizationStatus returned unknown value");
            handler(NO, nil);
            break;
    }
}

#pragma mark - Geo Location Picking

//@synthesize geoLocationViewController = _geoLocationViewController;
@synthesize modalLocationPickerHelper = _modalLocationPickerHelper;

- (UINavigationController*) modalLocationPickerHelper {
    if (_modalLocationPickerHelper == nil) {
//        self.geoLocationViewController.delegate = self;
        _modalLocationPickerHelper = [_viewController.storyboard instantiateViewControllerWithIdentifier: @"ModalGeoLocationViewController"];
        NSLog(@"geo picker: %@", _modalLocationPickerHelper.childViewControllers[0]);
        ((GeoLocationPicker*)[_modalLocationPickerHelper childViewControllers][0]).delegate = self;
    }
    return _modalLocationPickerHelper;
}
- (void) pickGeoLocation {
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"permission_denied_title", nil)
                                                         message: HXOLocalizedString(@"permission_denied_location", nil, HXOAppName())
                                                 completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { }
                                               cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                               otherButtonTitles: nil];
        [alert show];
    } else {
        [_viewController presentViewController: self.modalLocationPickerHelper animated: YES completion: nil];
    }
}

- (void) locationPicker:(GeoLocationPicker *)picker didPickLocation:(MKPointAnnotation*)placemark preview:(UIImage *)preview {
    if (placemark != nil && preview != nil) {
        NSDictionary *myAttachmentInfo = @{@"com.hoccer.xo.mediaType": @"geolocation",
                                           @"com.hoccer.xo.geolocation": placemark,
                                           @"com.hoccer.xo.previewImage": preview};
        [self.delegate didPickAttachment: myAttachmentInfo];
    } else {
        NSLog(@"#ERROR:locationPicker:didPickLocation: missing placemark or preview");
    }
}

- (void) locationPickerDidCancel:(GeoLocationPicker *)picker {
}


- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [AppDelegate setBlackFontStatusbarForViewController:viewController];
}

#pragma mark - image/video picking


- (void) showImagePickerWithSource: (UIImagePickerControllerSourceType) sourceType withVideo: (BOOL) videoFlag {
    
    UIImagePickerController * picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = sourceType;
    picker.modalPresentationStyle = UIModalPresentationCurrentContext;//UIModalPresentationCurrentContext;
    picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
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
    
    [self registerBackgroundTask];

    // Hack to make sure the camera picker will appear in portrait mode
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];

    // Show camera view controller.
    [_viewController presentViewController: picker animated: YES completion:^{
        NSLog(@"showImagePickerWithSource completion");
    }];
    
}

- (void) showMediaPicker {
    
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny];
    
    mediaPicker.delegate = self;
    mediaPicker.allowsPickingMultipleItems = NO;
    mediaPicker.prompt = nil;

    [_viewController presentViewController:mediaPicker animated:YES completion: nil];
    [AppDelegate setBlackFontStatusbarForViewController:_viewController];
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
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        NSString * mediaType = info[UIImagePickerControllerMediaType];
        BOOL shouldSaveImages = [self.delegate respondsToSelector: @selector(shouldSaveImagesToAlbum)] && [self.delegate shouldSaveImagesToAlbum];
        BOOL shouldSaveVideos = [self.delegate respondsToSelector: @selector(shouldSaveVideosToAlbum)] && [self.delegate shouldSaveVideosToAlbum];

        if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeImage) && shouldSaveImages) {
            UIImageWriteToSavedPhotosAlbum(info[UIImagePickerControllerOriginalImage], nil, nil, nil);
        } else if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeVideo) && shouldSaveVideos) {
            // TODO: UISaveVideoAtPathToSavedPhotosAlbum
            NSLog(@"Saving videos not yet implemented");
        }
    }    
    [self.delegate didPickAttachment: info];
    [self unregisterBackgroundTask];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [_viewController dismissViewControllerAnimated: YES completion: nil];
    [self unregisterBackgroundTask];
}

// we do this to avoid problems when the app is sent to background while a video export session is in progress
- (void) registerBackgroundTask {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        NSLog(@"#WARNING: AttachmentPickerController: trying to registering background task while one is already registered");
    }
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }];
}

- (void) unregisterBackgroundTask {
    UIApplication *app = [UIApplication sharedApplication];
    [app endBackgroundTask:_backgroundTask];
    _backgroundTask = UIBackgroundTaskInvalid;
}


#pragma mark - Multi Image/Video Picking

- (void) pickMultipleImages: (NSArray*) selectedAssets {
    CTAssetsPickerController * picker = [[CTAssetsPickerController alloc] init];
    picker.delegate = self;
    /*
    NSMutableArray * selectedAssets = [NSMutableArray array];
    for (NSURL * assetURL in selectedURLs) {
        NSLog(@"multi images: TODO - construct ALAsset from URL %@", assetURL);
        // [selectedAssets addObject: // Construct ALAsset from URL here ];
    }
    */
    picker.selectedAssets = [NSMutableArray arrayWithArray: selectedAssets];
    [_viewController presentViewController: picker animated: YES completion: nil];
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)assets {
    for (ALAsset * asset in assets) {
        NSLog(@"multi images: picked %@", asset);
    }
    [self.delegate didPickAttachment: assets];
    [_viewController dismissViewControllerAnimated: YES completion: nil];
}


@end

@implementation AttachmentPickerItem
@end
