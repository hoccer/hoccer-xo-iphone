//
//  Attachment.m
//  HoccerXO
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"

#import <Foundation/NSURL.h>
#import <MediaPlayer/MPMoviePlayerController.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVFoundation.h>
#import <AddressBookUI/AddressBookUI.h>

//#import <CommonCrypto/CommonDigest.h>
//#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>

#import "HXOMessage.h"
#import "Delivery.h"
#import "Group.h"
#import "Preview.h"

#import "HXOBackend.h"
#import "AppDelegate.h"
#import "CryptingInputStream.h"
#import "HXOUserDefaults.h"
#import "UIImage+ScaleAndCrop.h"
#import "ABPersonVCardCreator.h"
#import "ABPersonCreator.h"
#import "Vcard.h"
#import "GCHTTPRequestOperation.h"
#import "GCNetworkRequest.h"
#import "Collection.h"
#import "CollectionItem.h"
#import "GCNetworkQueue.h"

#import "Contact.h"

#import "HXOUI.h"

#import "NSData+Base64.h"

#import "NSString+StringWithData.h"

#import "NSData+NSInputStream.h"

#define TRANSFER_TRACE ([[self verbosityLevel]isEqualToString:@"moretrace"])
#define CONNECTION_TRACE ([[self verbosityLevel]isEqualToString:@"trace"] || TRANSFER_TRACE)

#define CONNECTION_DELEGATE_DEBUG   NO
#define URL_TRANSLATION_DEBUG       NO

#define TRACE_ATTACHMENT_FAULTING   NO
#define TRACE_ATTACHMENT_DELETION   NO

//#define LET_UPLOAD_FAIL
//#define LET_DOWNLOAD_FAIL

//#define NO_DOWNLOAD_RESUME
//#define NO_UPLOAD_RESUME


@interface Attachment()

#if defined(LET_DOWNLOAD_FAIL) || defined(NO_DOWNLOAD_RESUME) || defined(NO_UPLOAD_RESUME)
@property BOOL didResume;
@property NSInteger resumeSize;
#endif

@property (nonatomic) NSString * primitiveHumanReadableFileName;
@property (nonatomic) NSString * primitiveMediaType;
@property (nonatomic) NSString * primitiveMimeType;

@end

@implementation Attachment
{
    NSString * _verbosityLevel;
    NSError * _transferError;
    UIBackgroundTaskIdentifier _backgroundTaskId;
}

@dynamic localURL;
@dynamic mimeType;
@dynamic primitiveMimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic primitiveMediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic primitiveHumanReadableFileName;
@dynamic contentSize;
@dynamic aspectRatio;

@dynamic remoteURL;
@dynamic uploadURL;

@dynamic transferSize;
@dynamic cipherTransferSize;
@dynamic cipheredSize;
@dynamic transferFailures;
@dynamic playable;
@dynamic previewImageData;

@dynamic message;
@dynamic collectionItems;

@dynamic sourceMAC;
@dynamic destinationMAC;

@dynamic sourceMACString;

@dynamic transferFailed;
@dynamic transferPaused;
@dynamic transferAborted;

@dynamic width;                  // width for images and movies
@dynamic height;                 // width for images and movies
@dynamic entityTag;              // some content (file) unique tag that changes when the content changes
@dynamic duplicate;              // set to "YES" when there is at another attachment with the same content url that has the duplicate value not set
@dynamic universalType;          // the UTI
@dynamic creationDate;           // date when this record was created

@dynamic fileStatus;
@dynamic fileModificationDate;
@dynamic savedByContact;

@dynamic previewStore;

@dynamic attachmentJsonString;
@dynamic attachmentJsonStringCipherText;

@dynamic origCryptedJsonString;

@dynamic state;
@dynamic available;
@dynamic uploadable;

@synthesize transferConnection = _transferConnection;
@synthesize transferError = _transferError;
@synthesize transferHttpStatusCode;
@synthesize chatBackend = _chatBackend;
//@synthesize previewImage = _previewImage;
@dynamic previewImage;
@synthesize uiDelegate;
@synthesize decryptionEngine;
@synthesize encryptionEngine;
@synthesize transferRetryTimer = _transferRetryTimer;
@synthesize resumePos;
@synthesize previewIcon = _previewIcon;

#if defined(LET_DOWNLOAD_FAIL) || defined(NO_DOWNLOAD_RESUME) || defined(NO_UPLOAD_RESUME)
@synthesize didResume; // DEBUG
@synthesize resumeSize; // DEBUG
#endif
- (void) setTransferRetryTimer:(NSTimer*) theTimer {
    if (theTimer.isValid) {
        [self notifyTransferScheduled];
    }
    _transferRetryTimer = theTimer;
}

+ (NSArray*)allMediaTypes {
    return @[@"image",@"video",@"audio",@"vcard",@"geolocation",@"data"];
}

+ (NSArray*)audioVideoMediaTypes {
    return @[@"video",@"audio"];
}

+ (NSArray*)imageMediaTypes {
    return @[@"image"];
}

+ (NSArray*)audioMediaTypes {
    return @[@"audio"];
}

+ (NSArray*)visualMediaTypes {
    return @[@"image", @"video"];
}

+ (NSArray*)otherMediaTypes {
    return @[@"vcard",@"geolocation",@"data"];
}

- (void) awakeFromInsert {
    [super awakeFromInsert];
    self.creationDate = [NSDate date];
    // or [self setPrimitiveDate:[NSDate date]];
    // to avoid triggering KVO notifications
    
}

-(NSData*)previewImageData {
    return self.previewStore.imageData;
}

-(void)setPreviewImageData:(NSData*)data {
    if (self.previewStore != nil) {
        self.previewStore.imageData = data;
    } else {
        NSManagedObjectContext * context = self.managedObjectContext;
        
        if (context == nil) {
            NSLog(@"#ERROR: Attachment:setPreviewImageData: attachment context is nil");
        } else {
            Preview *store = [NSEntityDescription insertNewObjectForEntityForName:[[Preview class] entityName] inManagedObjectContext:context];
            store.attachment = self;
            self.previewStore = store;
            store.imageData = data;
        }
    }
}

+(NSString*) getStateName:(AttachmentState)state {
    
    NSArray * TransferStateName = @[@"detached",
                                @"empty",
                                @"transfered",
                                @"no transfer url",
                                @"transfers exhausted",
                                @"transfering",
                                @"transfer scheduled",
                                @"upload incomplete",
                                @"download incomplete",
                                @"transfer on hold",
                                @"wants transfer",
                                @"transfer paused",
                                @"transfer aborted"];
    if (state <= kAttachmentWantsTransfer) {
        return TransferStateName[state];
    }
    return nil;
}

// The attachment state is implicitly determined by the object state; there is no state variable
// - a completed transfer is indicated when transferSize equals contentSize
// - an ongoing transfer is indicated by a non-nil transferConnection
// - a schedules retry is indicated by a non-nil transferRetryTimer
// - a manual abort is indicated by a non-nil transferAborted date
// - a manual pause is indicated by a non-nil transferPaused date
// - an automatic hold is determined by contentSize and limit settings
// - once a transfer has been started, it is no longer held by transfer limits, but can be paused or aborted 

- (AttachmentState) state {
    AttachmentState myState = [self _state];
    if (CONNECTION_TRACE) {
        NSString * name;
        if (self.contentURL == nil) {
            name = self.ownedURL.lastPathComponent;
        } else {
            name = self.contentURL.lastPathComponent;
        }
        NSLog(@"Attachment '%@' state='%@'",name, [Attachment getStateName:myState]);
    }
    return myState;
}


- (AttachmentState) _state {
    if (self.contentSize == nil || [self.contentSize isEqualToNumber:@(0)]) {
        return kAttachmentEmpty;
    }
    if (self.message == nil) {
        return kAttachmentDetached;
    }
    if ([self.contentSize isEqualToNumber: self.transferSize]) {
        return kAttachmentTransfered;
    }
    if (self.remoteURL == nil || self.remoteURL.length == 0) {
        return kAttachmentNoTransferURL;
    }
    long long maxRetries = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentDownloadRetries] longLongValue];
    if (self.transferFailures > maxRetries) {
        return kAttachmentTransfersExhausted;
    }
    if (self.transferAborted != nil) {
        return kAttachmentTransferAborted;
    }
    if (self.transferPaused != nil) {
        return kAttachmentTransferPaused;
    }
    if (self.transferConnection != nil) {
        return kAttachmentTransfering;
    }
    if (self.transferRetryTimer.isValid) {
        return kAttachmentTransferScheduled;
    }
    if ([self.transferSize longLongValue]> 0) {
        if (self.outgoing) {
            return kAttachmentUploadIncomplete;
        }
        return kAttachmentDownloadIncomplete;
    }
    if (self.message.isIncoming && [self overTransferLimit:NO]) {
        return kAttachmentTransferOnHold;
    }

    return kAttachmentWantsTransfer;
}

-(UIImage*)previewImage {
    if (self.contentURL.lastPathComponent != nil) {
        return [AppDelegate.instance getCachedPreviewImagWithName:self.contentURL.lastPathComponent];
    } else {
        return nil;
    }
}

-(void)setPreviewImage:(UIImage *)previewImage {
    if (self.contentURL.lastPathComponent != nil) {
        [AppDelegate.instance cachePreviewImage:previewImage withName:self.contentURL.lastPathComponent];
    }
}

- (BOOL) outgoing {
    return self.message.isOutgoing;
}

- (BOOL) incoming {
    return self.message.isIncoming;
}

- (BOOL) available {
    AttachmentState myState = self.state;
    return (myState == kAttachmentTransfered || (self.outgoing && (myState != kAttachmentEmpty)) || (myState == kAttachmentDetached));
}

- (BOOL) uploadable {
    AttachmentState myState = self.state;
    return (myState == kAttachmentWantsTransfer || myState == kAttachmentUploadIncomplete) && self.outgoing && ![self fileUnavailable];
}

- (BOOL) downloadable {
    AttachmentState myState = self.state;
    return (myState == kAttachmentWantsTransfer || myState == kAttachmentDownloadIncomplete) && !self.outgoing;
}


- (BOOL) overTransferLimit:(BOOL)isOutgoing {
    BOOL reachableViaWLAN = [self.chatBackend.delegate.internetReachabilty isReachableViaWiFi];
    if (isOutgoing) {
        long long uploadLimit;
        if (reachableViaWLAN) {
            uploadLimit= [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoUploadLimitWLAN] longLongValue];
        } else {
            uploadLimit= [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoUploadLimitCellular] longLongValue];
        }
        if (uploadLimit && [self.contentSize longLongValue] > uploadLimit) {
            return YES;
        }
    } else {
        // incoming
        Delivery * delivery = self.message.deliveries.anyObject;
        BOOL wwAutoDownload = [[HXOUserDefaults standardUserDefaults] boolForKey:kHXOWorldwideAutoDownload];
        if (!wwAutoDownload &&
            (delivery.group.isWorldwide ||
             (delivery.sender.isGroupFriend &&  delivery.sender.isWorldwideContact)))
        {
            return YES;
        }
        
        long long downloadLimit;
        if (reachableViaWLAN) {
            downloadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoDownloadLimitWLAN] longLongValue];
        } else {
            downloadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoDownloadLimitCellular] longLongValue];
        }
        if (downloadLimit && [self.contentSize longLongValue] > downloadLimit) {
            return YES;
        }
    }
    return NO;
}

- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"attachmentVerbosity"];
    }
    return _verbosityLevel;
}

+ (NSNumber *) fileSize: (NSString *) fileURL withError: (NSError**) myError {
    if (myError != nil) {
        *myError = nil;
    }
    NSString * myPath = [[NSURL URLWithString: fileURL] path];
    NSNumber * result =  @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:myError] fileSize]);
    if (myError != nil && *myError != nil) {
        NSLog(@"ERROR: can not determine size of file '%@', error=%@", myPath, *myError);
        result = @(-1);
    }
    // NSLog(@"Attachment filesize = %@ (of file '%@')", result, myPath);
    return result;
}

- (HXOBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }
    
    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;
    
}

- (NSURL *) contentURL {
    if (self.localURL != nil) {
        return [NSURL URLWithString: self.localURL];
    } else if (self.assetURL != nil) {
        return [NSURL URLWithString: self.assetURL];
    }
    return nil;
};

- (NSURL *) otherContentURL {
    if (self.localURL != nil) {
        if (self.assetURL != nil) {
            return [NSURL URLWithString: self.assetURL];
        }
    }
    return nil;
};

- (BOOL)fileUnavailable {
    NSError *myError = nil;
    if (self.localURL != nil) {
        NSNumber * currentContentSize = [Attachment fileSize: self.localURL withError:&myError];
        if (myError != nil) {
            //NSLog(@"ERROR: failed to get size for file %@", self.localURL);
            return YES;
        }
        if (currentContentSize == 0) {
            return YES;
        }
    }
    return NO;
}
/*
- (void)protectFile {
    if (self.localURL != nil && self.available) {
        NSString * fullPath = [[NSURL URLWithString: self.localURL] path];
        if ([AppDelegate isUserReadWriteFile:fullPath]) {
            [AppDelegate setPosixPermissionsReadOnlyForPath:fullPath];
        }
    }
}

- (void)unprotectFile {
    if (self.localURL != nil && self.available) {
        NSString * fullPath = [[NSURL URLWithString: self.localURL] path];
        if (![AppDelegate isUserReadWriteFile:fullPath]) {
            [AppDelegate setPosixPermissionsReadWriteForPath:fullPath];
        }
    }
}
*/
- (void) useURLs:(NSString *)theURL anOtherURL:(NSString *)theOtherURL {
    NSURL * url = [NSURL URLWithString: theURL];
    if (theURL != nil) {
        if ([url.scheme isEqualToString: @"file"]) {
            self.localURL = theURL;
        } else if ([url.scheme isEqualToString: @"assets-library"] || [url.scheme isEqualToString: @"ipod-library"]) {
            self.assetURL = theURL;
        } else {
            NSLog(@"ERROR:unhandled URL scheme %@", url.scheme);
        }
    }
    if (theOtherURL != nil) {
        NSURL* anOtherUrl = [NSURL URLWithString: theOtherURL];
        if ([anOtherUrl.scheme isEqualToString: @"file"]) {
            self.localURL = theOtherURL;
        } else if ([anOtherUrl.scheme isEqualToString: @"assets-library"] || [url.scheme isEqualToString: @"ipod-library"]) {
            self.assetURL = theOtherURL;
        } else {
            NSLog(@"ERROR: unhandled URL otherURL scheme %@", anOtherUrl.scheme);
        }
    } else if (theURL == nil) {
        NSLog(@"ERROR: both urls are nil");
    }
    if (self.mimeType == nil && self.localURL != nil) {
        self.mimeType = [Attachment mimeTypeFromURLExtension: self.localURL];
    }
    if (self.mimeType == nil && self.assetURL != nil) {
        self.mimeType = [Attachment mimeTypeFromURLExtension: self.assetURL];
    }
    
    NSError *myError = nil;
    if (self.localURL != nil) {
        self.contentSize = [Attachment fileSize: self.localURL withError:&myError];
        if (myError != nil) {
            NSLog(@"ERROR: failed to get size for file %@", self.localURL);
        }
        // NSLog(@"File Size = %@ (of file '%@')", self.contentSize, self.localURL);
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:NULL];
        if (attributes) {
            self.entityTag= [AppDelegate etagFromAttributes:attributes];
            self.fileModificationDate = [attributes fileModificationDate];
        }
    } else if (self.assetURL != nil) {
        [self assetSizer:^(int64_t theSize, NSError * theError) {
            self.contentSize = @(theSize);
            // NSLog(@"Asset Size = %@ (of file '%@')", self.contentSize, self.assetURL);
        } url:self.assetURL];
    } else {
        NSLog(@"ERROR: both urls are nil, could not determine content size");
    }
    self.creationDate = [NSDate new];
    [self computeSourceMac];
}

// loads or creates an image representation of the attachment and calls ImageLoaderBlock when ready
// Note: this function will not modify attachment object
- (void) loadImage: (ImageLoaderBlock) block {
    if ([self.mediaType isEqualToString: @"image"]) {
        [self loadImageAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"video"]) {
        [self loadVideoAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"audio"]) {
        [self loadAudioAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"vcard"]) {
        [self loadVcardAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"geolocation"]) {
        [self loadGeoLocationAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"data"]) {
        [self loadDataAttachmentImage: block];
    } else {
        NSLog(@"WARNING - Attachment loadImage: unhandled attachment type %@", self.mediaType);
    }
}


- (void) setPreviewImageFromImage:(UIImage*) theFullImage {
    float previewWidth = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOPreviewImageWidth] floatValue];
    if (previewWidth > theFullImage.size.width) {
        previewWidth = theFullImage.size.width; // avoid scaling up preview
    }
    //if (!(self.aspectRatio > 0)) {
        [self setAspectRatioForImage:theFullImage];
    //}
    if (previewWidth == 0) {
        // handle no preview image case
        self.previewImage = theFullImage;
        self.previewImageData = UIImagePNGRepresentation(self.previewImage);
        return;
    }
    if ([self.mediaType isEqualToString: @"geolocation"]) {
        self.previewImage = theFullImage;
    } else {
        self.previewImage = [theFullImage imageScaledToSize:CGSizeMake(previewWidth, previewWidth/self.aspectRatio)];
    }

#if 0
    // as a result of this benchwork we use JPEG previews;
    // JPEG previews are 5-10 times smaller on disk and compression is
    // 5-10 times faster; decompression takes only 10-20% longer and
    // are negligable anyway (< 1ms)
    // preview sizes with a width of 200 (which is 400 pixels on 
    NSDate * start = [NSDate date];
    NSData * myJPEG = UIImageJPEGRepresentation(self.previewImage, 0.9);
    NSDate * jpgReady = [NSDate date];
    NSData * myPNG = UIImagePNGRepresentation(self.previewImage);
    NSDate * pngReady = [NSDate date];
    
    NSDate * startL = [NSDate date];
    UIImage * myJPEGImage = [UIImage imageWithData:myJPEG];
    NSDate * jpgReadyL = [NSDate date];
    UIImage * myPNGImage = [UIImage imageWithData:myPNG];
    NSDate * pngReadyL = [NSDate date];
    
    NSLog(@"PNG size = %d, create time %f, load time %f", myPNG.length, [pngReady timeIntervalSinceDate:jpgReady],[pngReadyL timeIntervalSinceDate:pngReadyL]);
    NSLog(@"JPG size = %d, create time %f, load time %f", myJPEG.length, [jpgReady timeIntervalSinceDate:start],[jpgReadyL timeIntervalSinceDate:startL]);
    
    NSLog(@"JPG orienation = %d, PNG orientation = %d", myJPEGImage.imageOrientation, myPNGImage.imageOrientation);
    NSLog(@"JPG scale = %f, PNG scale = %f", myJPEGImage.scale, myPNGImage.scale);
    self.previewImageData = myJPEG;
#else
    if ([self.mediaType isEqualToString: @"geolocation"]) {
        // but not with geolocation previews ... they look like crap when compressed with jpeg
        self.previewImageData = UIImagePNGRepresentation(self.previewImage);
    } else {
        float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        self.previewImageData = UIImageJPEGRepresentation(self.previewImage, photoQualityCompressionSetting/10.0);
    }
#endif
}

- (void) setAspectRatioForImage:(UIImage*) theImage {
    if (theImage.size.height == 0) {
        self.aspectRatio = 1;
    } else {
        self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
    }
    self.width = theImage.size.width;
    self.height = theImage.size.height;
}

- (UIImage *)previewIcon {
    if (_previewIcon == nil) {
        NSString * largeIconName = @"cnt-download"; // use as default icon
        if ([self.mediaType isEqualToString: @"vcard"]) {
            largeIconName = @"chatbar-attachment-icon-contact";
        }  else if ([self.mediaType isEqualToString: @"geolocation"]) {
            largeIconName = @"chatbar-attachment-icon-location";
        }  else if ([self.mediaType isEqualToString: @"audio"]) {
            if ([self.humanReadableFileName hasPrefix:@"recording"]) {
                largeIconName = @"chatbar-attachment-icon-record";
            } else {
                largeIconName = @"chatbar-attachment-icon-music";
            }
        }  else if ([self.mediaType isEqualToString: @"data"]) {
            largeIconName = @"chatbar-attachment-icon-data";
        }
        // NSLog(@"previewIcon: largeIconName=%@",largeIconName);
        if (largeIconName != nil) {
            _previewIcon = [UIImage imageNamed:largeIconName];
        }
    }
    
    // NSLog(@"previewIcon: returning%@",_previewIcon);
    return _previewIcon;
}

- (void) loadPreviewImageIntoCacheWithCompletion:(CompletionBlock)finished {
    // NSLog(@"loadPreviewImageIntoCacheWithCompletion");
    if (self.previewImageData != nil && self.previewImageData.length > 0) {
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database");
        // NSDate * start = [NSDate date];
        self.previewImage = [UIImage imageWithData:self.previewImageData scale: [UIScreen mainScreen].scale];
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database took %f ms.", -[start timeIntervalSinceNow]*1000);
        //if (!(self.aspectRatio > 0)) {
            [self setAspectRatioForImage:self.previewImage];
        //}

        if (finished != nil) {
            if (self.previewImage != nil) {
                finished(nil);
            } else {
                NSString * myDescription = @"Attachment could not load preview image from database";
                finished([NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 670 userInfo:@{NSLocalizedDescriptionKey: myDescription}]);
            }
        }
    } else {
        // create preview by loading full size image
        // TODO: guard against calling this over and over again if the attachment does not have an image
        [self loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"loadImage for preview done");
            if (theImage) {
                [self setPreviewImageFromImage:theImage];
                if (finished != nil) {
                    finished(nil);
                }
            } else {
                // Not an actual error. Vcards and audio files do not neccesariliy have an image.
                //NSLog(@"NOTE: Failed to get image %@", error);
                if (finished != nil) {
                    finished(error);
                }
            }
        }];
    }
}

- (void) ensurePreviewImageWithCompletion:(CompletionBlock)finished {
    if (self.previewImage != nil) {
        if (finished != nil) {
            finished(nil);
        }
    } else {
        [self loadPreviewImageIntoCacheWithCompletion:finished];
    }
}



+ (BOOL) tooLargeImage:(UIImage *)theFullImage {
    NSInteger photoQualityKiloPixelSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoSize"] integerValue];
    NSInteger photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] integerValue];
    double fullKiloPixelCount = theFullImage.size.height * theFullImage.size.width / 1000.0;
    if ((photoQualityKiloPixelSetting == 0 || fullKiloPixelCount <= photoQualityKiloPixelSetting) && photoQualityCompressionSetting == 10) {
        return NO;
    }
    return YES;
}


+ (UIImage *) qualityAdjustedImage:(UIImage *)theFullImage {
    NSInteger photoQualityKiloPixelSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoSize"] integerValue];
    double fullKiloPixelCount = theFullImage.size.height * theFullImage.size.width / 1000.0;
    if (photoQualityKiloPixelSetting == 0 || fullKiloPixelCount <= photoQualityKiloPixelSetting) {
        return theFullImage;
    }
    // too many pixels for our quality setting, lets reduce
    double reductionFactor = sqrt(fullKiloPixelCount / photoQualityKiloPixelSetting);
    CGSize newSize = CGSizeMake((int)(theFullImage.size.width/reductionFactor), (int)(theFullImage.size.height/reductionFactor));
    NSLog(@"qualityAdjustedImage: original kpix %f, limit kpix %ld, new kpix %f",fullKiloPixelCount, (long)photoQualityKiloPixelSetting, newSize.width*newSize.height/1000);
    return [theFullImage imageScaledToSize:newSize];
}


- (void) makeImageAttachment:(NSString *)theURL anOtherURL:(NSString *)otherURL image:(UIImage*)theImage withCompletion:(CompletionBlock)completion  {
    self.mediaType = @"image";
    
    [self useURLs: theURL anOtherURL:otherURL];
    
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for image/jpeg");
        self.mimeType = @"image/jpeg";        
    }
    
    if (theImage != nil) {
        [self setPreviewImageFromImage:theImage];
        if (completion != nil) {
            completion(nil);
        }
    } else {
        [self loadPreviewImageIntoCacheWithCompletion: completion];
    }
}

- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion{
    self.mediaType = @"video";
    
    [self useURLs: theURL anOtherURL: theOtherURL];
    
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for video/quicktime");
        self.mimeType = @"video/quicktime";
    }

    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeAudioAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion{
    // TODO: handle also mp3 etc.
    self.mediaType = @"audio";
    self.mimeType = @"audio/mp4";

    // NSLog(@"makeAudioAttachment theURL=%@, theOtherURL=%@", theURL, theOtherURL);

    [self useURLs: theURL anOtherURL: theOtherURL];
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for audio/mp4");
        self.mimeType = @"audio/mp4";
    }
    
    [self determinePlayability];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeVcardAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion {
    self.mediaType = @"vcard";
    self.mimeType = @"text/vcard";    
    [self useURLs: theURL anOtherURL: theOtherURL];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeGeoLocationAttachment: (NSString*) theURL anOtherURL: (NSString*) theOtherURL withCompletion: (CompletionBlock) completion {
    self.mediaType = @"geolocation";
    self.mimeType = @"application/json";
    [self useURLs: theURL anOtherURL: theOtherURL];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeDataAttachment: (NSString*) theURL anOtherURL: (NSString*) theOtherURL withCompletion: (CompletionBlock) completion {
    self.mediaType = @"data";
    if (self.mimeType == nil) {
        self.mimeType = @"application/octet-stream";
    }
    [self useURLs: theURL anOtherURL: theOtherURL];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

// works only for geolocations right now 
- (void) loadAttachmentDict:(DictLoaderBlock) block {
    if (![self.mediaType isEqualToString:@"geolocation"]) {
        block(nil, nil);
        return;
    }
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    NSError * error = nil;
    NSDictionary * geoLocation = nil;
    NSData * jsonData = nil;
    NSURL * url = nil;
    @try {
        url = self.contentURL;
        jsonData = [NSData dataWithContentsOfURL: url];
        geoLocation = [NSJSONSerialization JSONObjectWithData: jsonData options: 0 error: & error];
    } @catch (NSException * ex) {
        NSLog(@"ERROR parsing geolocation json, jsonData = %@, ex=%@, contentURL=%@", jsonData, ex, url);
    }
    block(geoLocation, error);
}

- (void) assetSizer: (SizeSetterBlock) block url:(NSString*)theAssetURL {
    // NSLog(@"assetSizer");
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        // NSLog(@"assetSizer result");
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        int64_t mySize = [rep size];
        // NSLog(@"assetSizer calling block");
        block(mySize, nil);
        // NSLog(@"assetSizer calling ready");
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];

}

#if CHEESY_PLAYER
- (void) loadVideoAttachmentImage: (ImageLoaderBlock) block {

    // synchronous loading, maybe make it async at some point
    MPMoviePlayerController * movie = [[MPMoviePlayerController alloc]
                                       initWithContentURL:[NSURL URLWithString:self.localURL]];
    UIImage * myImage = [movie thumbnailImageAtTime:0.0 timeOption:MPMovieTimeOptionExact];
    block(myImage, nil);
}

#else

- (void) loadVideoAttachmentImage: (ImageLoaderBlock) block {
    
    AVURLAsset * asset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:self.localURL] options:nil];
    AVAssetImageGenerator *generate = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generate.appliesPreferredTrackTransform = YES;
    NSError *err = NULL;
    CMTime time = CMTimeMake(1, 60);
    CGImageRef imgRef = [generate copyCGImageAtTime:time actualTime:NULL error:&err];
    
    // NSLog(@"loadVideoAttachmentImage err==%@, imageRef==%@", err, imgRef);
    
    block([[UIImage alloc] initWithCGImage:imgRef], nil);
}
#endif

+ (NSArray *)artworksForFileAtFileURL:(NSString *)fileURL {
    NSMutableArray *artworkImages = [NSMutableArray array];
    NSURL *URL = [NSURL URLWithString: fileURL];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:URL options:nil];
    NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata  withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    
    for (AVMetadataItem *i in artworks) {
        NSString *keySpace = i.keySpace;
        NSData *imageData = nil;
        
        if ([keySpace isEqualToString:AVMetadataKeySpaceID3]) {
            // see http://stackoverflow.com/questions/25778757/getting-mp3-artwork-crashes-on-ios-8-but-works-on-ios-7
            if (TARGET_OS_IPHONE && NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
                imageData = [i.value copyWithZone:nil];
            } else {
                NSDictionary *d = [i.value copyWithZone:nil];
                if ([d isKindOfClass:[NSDictionary class]]) {
                    imageData = [d objectForKey:@"data"];
                }
            }
        } else if ([keySpace isEqualToString:AVMetadataKeySpaceiTunes]) {
            imageData = [i.value copyWithZone:nil];
        } else if ([keySpace isEqualToString:AVMetadataKeySpaceISOUserData]) {
            imageData = [i.value copyWithZone:nil];
        } else {
            NSLog(@"=== unhandled media item %@", i);
        }
        
        UIImage *im = nil;
        if (imageData) {
            im = [UIImage imageWithData:imageData];
        }
        if (im) {
            [artworkImages addObject:im];
        }
    }
    // NSLog(@"array description is %@", [artworkImages description]);
    return artworkImages;
}

- (void) loadAudioAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    NSArray * myArtworkImages = [[self class]artworksForFileAtFileURL: self.localURL];
    if ([myArtworkImages count]) {
        UIImage * myfirstImage = myArtworkImages[0];
        block(myfirstImage, nil);
    } else {
        block([[UIImage alloc]init], nil);
        //block([UIImage imageNamed:@"cover-art-fallback.png"], nil);
    }
}

- (void) loadDataAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    // block([UIImage imageNamed:@"audio-default.png"], nil);
    block([[UIImage alloc]init], nil);
}

- (void) loadVcardAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    Vcard * myVcard = [[Vcard alloc] initWithVcardURL:self.contentURL];
    if (myVcard != nil) {
        UIImage * myPreviewImage = [myVcard personImage];
        if (myPreviewImage) {
            block(myPreviewImage, nil);
            return;
        }
    }
    block([[UIImage alloc]init], nil);
}

- (void) loadGeoLocationAttachmentImage: (ImageLoaderBlock) block {

    [self loadAttachmentDict:^(NSDictionary * geoLocation, NSError * error) {
        if (geoLocation != nil) {
            NSData * imageData = [NSData dataWithBase64EncodedString: geoLocation[@"previewImage"]];
            block([UIImage imageWithData: imageData scale: [UIScreen mainScreen].scale], nil);
        } else {
            block(nil, error);
        }
    }];
}

- (void) loadImageAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL != nil) {
        UIImage * myImage = [UIImage imageWithContentsOfFile: [[NSURL URLWithString: self.localURL] path]];
        NSError * myError = nil;
        if (myImage == nil) {
            NSString * myDescription = [NSString stringWithFormat:@"Attachment loadImageAttachmentImage could not load image from path %@", [[NSURL URLWithString: self.localURL] path]];
            NSLog(@"%@", myDescription);
            myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 633 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        }
        block(myImage, myError);
    } else if (self.assetURL != nil) {
        // NSLog(@"loadImageAttachmentImage assetURL");
        //TODO: handle different resolutions. For now just load a representation that is suitable for a chat bubble
        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {
            // NSLog(@"loadImageAttachmentImage assetURL result");
            ALAssetRepresentation *rep = [myasset defaultRepresentation];
            //CGImageRef iref = [rep fullResolutionImage];
            CGImageRef iref = [rep fullScreenImage];
            if (iref) {
                // NSLog(@"loadImageAttachmentImage assetURL calling block");
                block([UIImage imageWithCGImage:iref], nil);
                // NSLog(@"loadImageAttachmentImage assetURL calling block done");
            }
        };
        
        //
        ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
        {
            NSLog(@"ERROR: Failed to get image %@ from asset library: %@", self.assetURL, [myerror localizedDescription]);
            block(nil, myerror);
        };
        
        if(self.assetURL && [self.assetURL length])
        {
            ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
            [assetslibrary assetForURL: [NSURL URLWithString: self.assetURL]
                           resultBlock: resultblock
                          failureBlock: failureblock];
        }
    } else {
        NSLog(@"WARNING: no image url");
        block(nil, nil);
    }
}

- (void) assetDataLoader: (DataSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        NSError * myError = nil;
        int64_t mySize = [rep size];
        Byte *buffer = (Byte *)malloc(mySize);
        NSUInteger bufferLen = [rep getBytes: buffer fromOffset:0 length:mySize error:&myError];
        NSData * myData = [NSData dataWithBytesNoCopy: buffer length: bufferLen];
        block(myData, myError);
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];
    
}

- (void) assetStreamLoader: (StreamSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        // NSLog(@"Attachment assetStreamLoader for self.assetURL=%@", self.self.assetURL);
    /*
        NSString * myPath = [rep filename];
        NSInputStream * myStream = [NSInputStream inputStreamWithFileAtPath:myPath];
        NSLog(@"Attachment assetStreamLoader returning input stream for file at path=%@", myPath);
     */
        // Just for testing purposes, we need a AssetInputStream here
        NSError * myError = nil;
        int64_t mySize = [rep size];
        Byte *buffer = (Byte *)malloc(mySize);
        NSUInteger bufferLen = [rep getBytes: buffer fromOffset:0 length:mySize error:&myError];
        NSData * myData = [NSData dataWithBytesNoCopy: buffer length: bufferLen];
        NSInputStream * myStream = [NSInputStream inputStreamWithData: myData];
        block(myStream, myError); // TODO: error handling
        return;
     };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];
    
}

- (void) uploadData {
    if (CONNECTION_TRACE) {NSLog(@"Attachment:upload uploadURL=%@, attachment=%@", self.uploadURL, self );}
    if (self.incoming) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        NSLog(@"upload of attachment still running");
        return;
    }
    [self withUploadData:^(NSData * myData, NSError * myError) {
        if (myError == nil) {
            // NSLog(@"Attachment:upload starting withUploadData");
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                                 absoluteURI:[HXOBackend checkForceFilecacheUrl:[self uploadURL]]
                                                 payloadData:myData
                                                 payloadStream:nil
                                                 headers:[self uploadHttpHeaders]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            [self notifyTransferStarted];
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (void) uploadStream {
    if (CONNECTION_TRACE) {NSLog(@"Attachment:uploadStream uploadURL=%@, attachment=%@", self.uploadURL, self );}
    if (self.incoming) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"upload of attachment still running");
        return;
    }
    if (self.state == kAttachmentTransfered) {
        NSLog(@"#WARNING: Attachment uploadStream: already transfered, uploadURL=%@, attachment.contentSize=%@", self.uploadURL, self.contentSize );
        return;
    }
    if (self.cipherTransferSize != nil && [self.cipherTransferSize longLongValue] > 0) {
        [self tryResumeUploadStream];
        return;
    }
#ifdef NO_UPLOAD_RESUME
    self.didResume = NO; // just for TESTING
#endif
    [self withUploadStream:^(NSInputStream * myStream, NSError * myError) {
        if (myError == nil) {
            // NSLog(@"Attachment:upload starting uploadStream");
            NSData * messageKey = self.message.cryptoKey;
            NSError * myError = nil;
            encryptionEngine = [[CryptoEngine alloc]
                                       initWithOperation:kCCEncrypt
                                       algorithm:kCCAlgorithmAES128
                                       options:kCCOptionPKCS7Padding
                                       key:messageKey
                                       IV:nil
                                       error:&myError];
            CryptingInputStream * myEncryptingStream = [[CryptingInputStream alloc] initWithInputStream:myStream cryptoEngine:encryptionEngine skipOutputBytes:0];
#define ORIG
#ifdef ORIG

// use TEST_WITH_DATA to find out whether our CryptingInputStream is causing upload problems in conjunction with NSURLRequest
//#define TEST_WITH_DATA
#ifdef TEST_WITH_DATA
            NSData * myData = [NSData dataWithContentsOfStream:myEncryptingStream initialCapacity:0 error:&myError];
            NSLog(@"myData length = %d, myError = %@", myData.length, myError);
#endif
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                                         absoluteURI:[HXOBackend checkForceFilecacheUrl:[self uploadURL]]
#ifdef TEST_WITH_DATA
                                                         payloadData:myData
                                                         payloadStream:nil
#else
                                                         payloadData:nil
                                                         payloadStream:myEncryptingStream
#endif
                                                         headers:[self uploadHttpHeadersWithCrypto]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            [self notifyTransferStarted];
            [self.chatBackend uploadStarted:self];
#else
            [self uploadFullStream:myEncryptingStream inQueue:[HXOBackend.instance attachmentUploadQueue] withLength:[self.cipheredSize longLongValue]
                        onProgress:^(NSUInteger bytesWritten, NSUInteger totalBytesWritten, NSUInteger totalBytesExpectedToWrite) {
                if ([self.cipherTransferSize integerValue] == 0) {
                    [self notifyTransferStarted];
                }
                self.cipherTransferSize = @([self.cipherTransferSize integerValue]+bytesWritten);
                [self notifyTransferProgress: [self.cipherTransferSize floatValue] / [self.cipheredSize floatValue]];
                
            } withCompletion:^(NSError *theError) {
                if (theError == nil) {
                    if (CONNECTION_TRACE) {NSLog(@"Attachment withUploadStream successfully uploaded attachment, size=%@", self.contentSize);}
                    // upload finished
                    if (![self.cipheredSize isEqualToNumber:self.cipherTransferSize]) {
                        NSLog(@"INFO: finishing upload, fixing cipherTransferSize mismatch");
                        self.cipherTransferSize = self.cipheredSize;
                    }
                    self.transferSize = self.contentSize;
                    [self.chatBackend uploadFinished:self];
                } else {
                    self.transferError = theError;
                    [self.chatBackend uploadFailed:self];
                }
                [self notifyTransferFinished];
            }];
#endif
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (void) uploadFullStream:(NSInputStream *)myStream inQueue:(GCNetworkQueue*)queue withLength:(long long)length onProgress:(UploadProgessBlock)progressBlock withCompletion:(CompletionBlock)handler {
    
    NSString * toURL = [HXOBackend checkForceFilecacheUrl:self.uploadURL];
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:toURL HTTPMethod:@"PUT" parameters:nil];
    NSDictionary * headers = [self uploadHttpHeadersWithCrypto];
    for (NSString *key in headers) {
        [request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
    }
    [request addValue:AppDelegate.instance.userAgent forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBodyStream:myStream];
    
    if (CONNECTION_TRACE) {NSLog(@"uploadFullStream: request header= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CONNECTION_TRACE) {
                              NSLog(@"uploadFullStream got response status = %d,(%@) headers=%@", (int)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"uploadFullStream response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode == 301 || response.statusCode == 308 || response.statusCode == 200) {
                              if (CONNECTION_TRACE) {NSLog(@"uploadFullStream: seems ok, lets check");}
                              [HXOBackend checkUploadStatus:toURL hasSize:length withCompletion:^(NSString *url, long long transferedSize, BOOL ok) {
                                  if (ok) {
                                      handler(nil);
                                  } else {
                                      NSString * myDescription = @"uploadFullStream check failed";
                                      // NSLog(@"%@", myDescription);
                                      NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.upload" code: 947 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                                      handler(myError);
                                  }
                              }];
                              
                          } else {
                              NSString * myDescription = [NSString stringWithFormat:@"uploadAvatar irregular response status = %d, headers=%@", (int)response.statusCode, response.allHeaderFields];
                              // NSLog(@"%@", myDescription);
                              NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.upload" code: 945 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                              handler(myError);
                          }
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"uploadFullStream error response status = %d, headers=%@, error=%@", (int)response.statusCode, response.allHeaderFields, error);
                               handler(error);
                               
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [self connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    [operation uploadProgressHandler:progressBlock];
    if (queue == nil) {
        [operation startRequest];
    } else {
        [queue enqueueOperation:operation];
    }
}

- (void) checkResumeUploadStream {
    if (CONNECTION_TRACE) {NSLog(@"checkResumeUploadStream uploadURL=%@, attachment=%@", self.uploadURL, self );}

    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:[HXOBackend checkForceFilecacheUrl:self.uploadURL] HTTPMethod:@"PUT" parameters:nil];
    NSDictionary * headers = [self uploadHttpHeadersForRequestingUploadedRange];
	for (NSString *key in headers) {
		[request addValue:[headers objectForKey:key] forHTTPHeaderField:key];
	}
	[request addValue:self.chatBackend.delegate.userAgent forHTTPHeaderField:@"User-Agent"];
    
    if (CONNECTION_TRACE) {NSLog(@"checkResumeUploadStream: request header for check= %@",request.allHTTPHeaderFields);}
    GCHTTPRequestOperation *operation =
    [GCHTTPRequestOperation HTTPRequest:request
                          callBackQueue:nil
                      completionHandler:^(NSData *data, NSHTTPURLResponse *response) {
                          if (CONNECTION_TRACE) {
                              NSLog(@"checkResumeUploadStream got response status = %d,(%@) headers=%@", (int)response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode != 404) {
                              NSDictionary * myHeaders = response.allHeaderFields;
                              
                              NSString * myRangeString = myHeaders[@"Range"];
                              
                              if (myRangeString != nil) {
                                  
                                  long long rangeStart;
                                  long long rangeEnd;
                                  long long contentLength;
                                  
                                  if ([HXOBackend scanRange:myRangeString
                                                 rangeStart:&rangeStart
                                                   rangeEnd:&rangeEnd
                                              contentLength:&contentLength])
                                  {
                                      [self resumeUploadStreamFromPosition:[NSNumber numberWithLongLong:rangeEnd]];
                                  } else {
                                      NSLog(@"checkResumeUploadStream could not parse Content-Range Header, headers=%@", response.allHeaderFields);
                                  }
                              } else {
                                  NSString * ContentLength = myHeaders[@"Content-Length"];
                                  if (ContentLength != nil && [ContentLength integerValue] == 0) {
                                      [self resumeUploadStreamFromPosition:@(0)];
                                      return;
                                  } else {
                                      NSLog(@"checkResumeUploadStream irregular Content-Length %@, response status = %d, headers=%@",ContentLength, (int)response.statusCode, response.allHeaderFields);
                                  }
                              }
                              
                          } else {
                              NSLog(@"checkResumeUploadStream irregular response status = %d, headers=%@", (int)response.statusCode, response.allHeaderFields);
                          }
                          [self.chatBackend uploadFailed:self];
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"checkResumeUploadStream error response status = %d, headers=%@, error=%@", (int)response.statusCode, response.allHeaderFields, error);
                               [self.chatBackend uploadFailed:self];
                           }
                       challengeHandler:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
                           [[HXOBackend instance] connection:connection willSendRequestForAuthenticationChallenge:challenge];
                       }
     ];
    [operation startRequest];
}

- (void) tryResumeUploadStream {
    if (CONNECTION_TRACE) {NSLog(@"tryResumeUploadStream uploadURL=%@, attachment=%@", self.uploadURL, self );}
    if (self.incoming) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"upload of attachment still running");
        return;
    }
    if (self.state == kAttachmentTransfered) {
        NSLog(@"#WARNING: Attachment uploadStream: already transfered, uploadURL=%@, attachment.contentSize=%@", self.uploadURL, self.contentSize );
        return;
    }
    [self checkResumeUploadStream];
}

- (void) resumeUploadStreamFromPosition:(NSNumber *)fromPos {
#ifdef NO_UPLOAD_RESUME
    self.didResume = YES; // just for TESTING
#endif
    if ([fromPos longLongValue] + 1 == [self.cipheredSize longLongValue]) {
        NSLog(@"Attachment:resumeUploadStreamFromPosition: upload has already been completed, fromPos=%@+1 == %@ (cipheredSize)", fromPos,self.cipheredSize);
        self.cipherTransferSize = self.cipheredSize;
        self.transferSize = self.contentSize;
        [self notifyTransferFinished];
        [self.chatBackend uploadFinished:self];
        return;
    }
    if ([fromPos longLongValue] + 1 > [self.cipheredSize longLongValue]) {
        NSLog(@"ERROR: Attachment:withUploadStream - fromPos %@ > cipheredSize %@, not resuming", fromPos, self.cipheredSize);
        [self.chatBackend uploadFailed:self];
        return;
    }
    
    [self withUploadStream:^(NSInputStream * myStream, NSError * myError) {
        if (myError == nil) {
            if (CONNECTION_TRACE) {NSLog(@"Attachment:resumeUploadStreamFromPosition: %@", fromPos);}
            NSData * messageKey = self.message.cryptoKey;
            NSError * myError = nil;
            encryptionEngine = [[CryptoEngine alloc]
                                initWithOperation:kCCEncrypt
                                algorithm:kCCAlgorithmAES128
                                options:kCCOptionPKCS7Padding
                                key:messageKey
                                IV:nil
                                error:&myError];
            CryptingInputStream * myEncryptingStream = [[CryptingInputStream alloc] initWithInputStream:myStream
                                                                                           cryptoEngine:encryptionEngine
                                                                                        skipOutputBytes:[fromPos integerValue]];
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                                         absoluteURI:[HXOBackend checkForceFilecacheUrl:self.uploadURL]
                                                         payloadData:nil
                                                       payloadStream:myEncryptingStream
                                                             headers:[self uploadHttpHeadersWithCryptoFromPos:fromPos]
                                        ];
            self.cipherTransferSize = fromPos;
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            [self notifyTransferStarted];
            [self.chatBackend uploadStarted:self];
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (NSString*) humanReadableFileName {
    [self willAccessValueForKey:@"humanReadableFileName"];
    NSString * filename = [self primitiveHumanReadableFileName];
    if (filename == nil) {
        if (self.mimeType && self.mediaType) {
            NSString * extension = [Attachment fileExtensionFromMimeType:self.mimeType];
            filename = [self.mediaType stringByAppendingPathExtension: extension];
        } else if (self.mediaType) {
            filename = self.mediaType;
        }
    }
    [self didAccessValueForKey:@"humanReadableFileName"];
    return filename;
}

- (void) setMediaType:(NSString *)mediaType {
    NSString * filename = [self primitiveHumanReadableFileName];
    if ( ! filename) { [self willChangeValueForKey: @"humanReadableFileName"]; }
    [self willChangeValueForKey: @"mediaType"];
    [self setPrimitiveMediaType: mediaType];
    [self didChangeValueForKey: @"mediaType"];
    if ( ! filename) { [self didChangeValueForKey: @"humanReadableFileName"]; }
}

- (void) setMimeType:(NSString *)mimeType {
    NSString * filename = [self primitiveHumanReadableFileName];
    if ( ! filename) { [self willChangeValueForKey: @"humanReadableFileName"]; }
    [self willChangeValueForKey: @"mimeType"];
    [self setPrimitiveMimeType: mimeType];
    [self didChangeValueForKey: @"mimeType"];
    if ( ! filename) { [self didChangeValueForKey: @"humanReadableFileName"]; }
}

- (void) upload {
    // [self uploadData];
    [self uploadStream];
}

- (NSNumber*) calcCipheredSize {
    NSError * myError = nil;
    NSData * messageKey = self.message.cryptoKey;
    CryptoEngine * myEncryptionEngine = [[CryptoEngine alloc]
                         initWithOperation:kCCEncrypt
                         algorithm:kCCAlgorithmAES128
                         options:kCCOptionPKCS7Padding
                         key:messageKey
                         IV:nil
                         error:&myError];

    return [NSNumber numberWithLongLong:[myEncryptionEngine calcOutputLengthForInputLength:[self contentSize].longLongValue]];
}


- (void) resumeDownload {
    if (CONNECTION_TRACE) {NSLog(@"Attachment resumeDownload remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );}
    if (self.outgoing) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoingFlag = %@", self.message.isOutgoingFlag);
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"download of attachment still running");
        return;
    }
    if (self.state == kAttachmentTransfered) {
        NSLog(@"#WARNING: Attachment download: already transfered, remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );
        return;
    }
    
    if (self.ownedURL == nil) {
        NSLog(@"can not resume, no local url");
        // create new destination file for download
        [self download];
        return;
    }
    
    NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:myPath]) {
        NSLog(@"resumeDownload: can not resume, no file at path %@, starting over", myPath);
        self.ownedURL = nil;
        [self download];
        return;
    }
    NSError * error = nil;
    long long fileSize = [[Attachment fileSize:self.ownedURL withError:&error] longLongValue];
    if (error != nil) {
        NSLog(@"resumeDownload: can't determine size of %@, error=%@, starting over", self.ownedURL, error);
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
        [self download];
        return;
    }
    if (fileSize < 16 || fileSize > [self.contentSize longLongValue]) {
        NSLog(@"resumeDownload: size of %@ too small or too large (%lld), starting over", self.ownedURL, fileSize);
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
        [self download];
        return;        
    }
    NSUInteger lastFullBlockPos = (fileSize / 16)*16 - 16;
   
    self.resumePos = lastFullBlockPos + 16;
    if (CONNECTION_TRACE) {NSLog(@"truncating file size %llu to size %@, lastFullBlockPos=%@", fileSize, @(self.resumePos), @(lastFullBlockPos));}
    [Attachment truncateFileAtPath:myPath toSize:resumePos];
             
    self.cipherTransferSize = [NSNumber numberWithLongLong:resumePos]; // set transfered size to resume position
    self.cipheredSize = [self calcCipheredSize];
    NSNumber * lastBytePos = [NSNumber numberWithLongLong:[self.cipheredSize longLongValue]-1];
    
    self.decryptionEngine = nil;
    NSDictionary * myHeaders = [self downloadHttpHeadersWithStart: [NSNumber numberWithLongLong:lastFullBlockPos] withEnd:lastBytePos];
    
    
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                                 absoluteURI:[HXOBackend checkForceFilecacheUrl:[self remoteURL]]
                                                 payloadData:nil
                                               payloadStream:nil
                                                     headers:myHeaders
                                ];
    if (CONNECTION_TRACE) {NSLog(@"try resume download with header = %@",myHeaders);}
#ifdef LET_DOWNLOAD_FAIL
    self.resumeSize = [self.cipheredSize longValue]- [self.cipherTransferSize longValue];
#endif
    self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self downloadDelegate]];
    [self registerBackgroundTask];
    [self notifyTransferStarted];
}

- (void) download {
#ifdef NO_DOWNLOAD_RESUME    
    self.didResume = NO; // just for TESTING
#endif
    if (CONNECTION_TRACE) {NSLog(@"Attachment download remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );}
    if (self.outgoing) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoingFlag = %@", self.message.isOutgoingFlag);
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"download of attachment still running");
        return;
    }
    if (self.state == kAttachmentTransfered) {
        NSLog(@"#WARNING: Attachment download: already transfered, remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );
        return;
    }
    
    if (self.ownedURL == nil) {
        // create new destination file for download
        //NSURL *appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
        NSURL * downloadURL = [self localUrlForDownload];
        NSError * error = [Attachment createFileAtURLPosix:downloadURL];
        if (error == nil) {
            self.ownedURL = [downloadURL absoluteString];
        } else {
            NSLog(@"Attachment: could not create file, error=%@", error);
            return;
        }
    } else {
#ifdef NO_DOWNLOAD_RESUME
        // without ranged requests, let us delete the file in case it is left over
        NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
#else
        [self resumeDownload];
        return;
#endif
    }
    
    NSData * messageKey = self.message.cryptoKey;
    if ([HXOBackend isInvalid:messageKey]) {
        NSLog(@"ERROR: invalid message key for attachment remoteURL=%@, attachment.contentSize=%@, contact=%@", self.remoteURL, self.contentSize, self.message.contact.nickName);
        return;
    }
    NSError * myError = nil;
    self.decryptionEngine = [[CryptoEngine alloc]
                               initWithOperation:kCCDecrypt
                               algorithm:kCCAlgorithmAES128
                               options:kCCOptionPKCS7Padding
                               key:messageKey
                               IV:nil
                               error:&myError];
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                                 absoluteURI:[HXOBackend checkForceFilecacheUrl:[self remoteURL]]
                                        payloadData:nil
                                        payloadStream:nil
                                        headers:[self downloadHttpHeaders]
                                ];

    // encryptionEngine just needed to determine the cipherTransferSize
    self.encryptionEngine = [[CryptoEngine alloc]
                             initWithOperation:kCCEncrypt
                             algorithm:kCCAlgorithmAES128
                             options:kCCOptionPKCS7Padding
                             key:messageKey
                             IV:nil
                             error:&myError];

    self.cipherTransferSize = [NSNumber numberWithLongLong:0];
    self.cipheredSize = [NSNumber numberWithLongLong:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].longLongValue]];
#ifdef LET_DOWNLOAD_FAIL
    self.resumeSize = [self.cipheredSize longValue];
#endif

    self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self downloadDelegate]];
    [self registerBackgroundTask];
    [self notifyTransferStarted];
}

- (void) downloadOnTimer: (NSTimer*) theTimer {
    if (theTimer != _transferRetryTimer) {
        NSLog(@"WARNING: downloadOnTimer: called by strange timer");
    } else {
        _transferRetryTimer = nil;
    }
    [self download];
}
    
- (void) pauseTransfer {
    if (self.transferPaused == nil && self.state >= kAttachmentTransfering && self.state <= kAttachmentWantsTransfer) {
        if (_transferConnection != nil) {
            [_transferConnection cancel];
            [self unregisterBackgroundTask];
            _transferConnection = nil;
        }
        NSLog(@"pausedTransfer transfer, cipherTransferSize=%@, cipheredSize=%@",self.cipherTransferSize,self.cipheredSize);
        self.transferPaused = [[NSDate alloc] init];
        if (self.outgoing) {
            [self.chatBackend uploadPaused:self];
        }
    }
}

- (void) unpauseTransfer {
    NSLog(@"unpausedTransfer");
    if (self.transferPaused != nil) {
        self.transferPaused = nil;
        if (self.outgoing) {
            [self.chatBackend uploadStarted:self];
            [self.chatBackend enqueueUploadOfAttachment:self];
            [self.chatBackend checkUploadQueue];
        } else {
            [self.chatBackend enqueueDownloadOfAttachment:self];
            [self.chatBackend checkDowloadQueue];
        }
    }
}

- (void) uploadOnTimer: (NSTimer*) theTimer {
    if (theTimer != _transferRetryTimer) {
        NSLog(@"WARNING: downloadOnTimer: called by strange timer");
    } else {
        _transferRetryTimer = nil;
    }
    [self upload];
}

- (void)pressedButton: (id)sender {
    // NSLog(@"Attachment pressedButton %@", sender);
    self.transferFailures = 0;
    if (self.outgoing) {
        // [self.chatBackend enqueueUploadOfAttachment:self];
        [self upload];
    } else {
        // [self.chatBackend enqueueDownloadOfAttachment:self];
        [self download];
    }
}

-(void) withUploadData: (DataSetterBlock) execution {
    if (self.localURL != nil) {
        // NSLog(@"Attachment withUploadData self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:myPath];
        // NSLog(@"Attachment return uploadData len=%d, path=%@", [data length], myPath);
        execution(data, nil); // TODO: better error handling
        return;
    }
    if (self.assetURL != nil) {
        // NSLog(@"Attachment uploadData assetURL=%@", self.assetURL);
        [self assetDataLoader: execution url: self.assetURL];
        return;
    }
    execution(nil, [NSError errorWithDomain:@"HoccerXO" code:1000 userInfo: nil]);
}

-(void) withUploadStream:(StreamSetterBlock) execution {
    if (self.localURL != nil) {
        // NSLog(@"Attachment withUploadStream self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        BOOL isDirectory;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:myPath isDirectory:&isDirectory];
        if (!exists || isDirectory) {
            execution(nil, [NSError errorWithDomain:@"HoccerXO" code:1101 userInfo: nil]);
            return;
        }
        NSInputStream * myStream = [NSInputStream inputStreamWithFileAtPath:myPath];
        // NSLog(@"Attachment returning input stream for file at path=%@", myPath);
        execution(myStream, nil); // TODO: better error handling
        return;
    }
    if (self.assetURL != nil) {
        // NSLog(@"Attachment withUploadStream assetURL=%@", self.assetURL);
        [self assetStreamLoader: execution url: self.assetURL];
        return;
    }
    execution(nil, [NSError errorWithDomain:@"HoccerXO" code:1000 userInfo: nil]);
}

-(void) computeMAC:(MACSetterBlock) setMAC {
    [self withUploadStream:^(NSInputStream *theStream, NSError *theError) {
        
        NSUInteger bufferSize = 8192;
        NSInteger read = 0;
        uint8_t     *buff = (uint8_t *)malloc(sizeof(uint8_t)*bufferSize);
        
        CC_SHA256_CTX ctx;
        CC_SHA256_Init(&ctx);
        
        [theStream open];
        
        do {
            read = [theStream read:buff maxLength:bufferSize];
            //NSLog(@"computeMAC: read %d bytes", read);
            if (read > 0) {
                CC_SHA256_Update(&ctx,buff,(CC_LONG)read);
            }
        } while (read > 0);
        
        free(buff);
        
        if (read < 0) {
            setMAC(nil,theStream.streamError);
            [theStream close];
            return;
        }
        [theStream close];
        
        NSMutableData * result = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final([result mutableBytes], &ctx);
        setMAC(result, nil);
    }];
}

-(void) computeSourceMac {
    __weak Attachment * weakSelf = self;
    [weakSelf computeMAC:^(NSData *theMAC, NSError *theError) {
        if (theError == nil && theMAC != nil) {
            weakSelf.sourceMAC = theMAC;
            NSLog(@"computeSourceMac: MAC=%@", self.sourceMACString);
        } else {
            NSLog(@"ERROR: failed to compute MAC for attachment URL %@, error = %@", [self contentURL], theError);
        }
    }];
}

-(void) computeDestMac {
    [self computeMAC:^(NSData *theMAC, NSError *theError) {
        if (theError == nil && theMAC != nil) {
            self.destinationMAC = theMAC;
            if (self.sourceMAC != nil) {
                if (![self.destinationMAC isEqualToData:self.sourceMAC]) {
                    NSLog(@"ERROR: MAC differs for attachment URL %@, source MAC = %@, computed MAC = %@", [self contentURL], [self.sourceMAC asBase64EncodedString], [self.destinationMAC asBase64EncodedString]);
                } else {
                    NSLog(@"computeDestMac: MAC=%@ ok", self.sourceMACString);
                }
            } else {
                NSLog(@"computeDestMac: No Source MAC, dest MAC =%@", self.sourceMACString);
            }
        } else {
            NSLog(@"ERROR: failed to compute MAC for attachment URL %@, error = %@", [self contentURL], theError);
        }
    }];
}

-(NSDictionary*) uploadHttpHeadersWithCrypto {
    
    self.cipheredSize = [NSNumber numberWithInteger:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].integerValue]];
    
    NSDictionary * headers = @{@"Content-Type"       : @"application/octet-stream",
                               @"Content-Length"     : [self.cipheredSize stringValue]};
    if (CONNECTION_TRACE) {NSLog(@"uploadHttpHeadersWithCrypto: headers=%@", headers);}
    return headers;
}

-(NSDictionary*) uploadHttpHeadersWithCryptoFromPos:(NSNumber*) start {
    
    self.cipheredSize = [NSNumber numberWithInteger:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].integerValue]];

    off_t end = [self.cipheredSize longLongValue] - 1;
    off_t size = end - [start longLongValue] + 1;

    NSString * range = [NSString stringWithFormat:@"bytes %@-%lld/%lld", start, end, [self.cipheredSize longLongValue]];
    NSDictionary * headers = @{@"Content-Range" : range,
                               @"Content-Type"  : @"application/octet-stream",
                               @"Content-Length": [@(size) stringValue]};
    if (CONNECTION_TRACE) {NSLog(@"uploadHttpHeadersWithCryptoFromPos: headers=%@", headers);}
    return headers;
}

-(NSDictionary*) uploadHttpHeadersForRequestingUploadedRange {            
    NSDictionary * headers = @{@"Content-Length": @"0"};
    if (CONNECTION_TRACE) {NSLog(@"uploadHttpHeadersWithFullRangeForHeadRequest: headers=%@", headers);}
    return headers;
}

-(NSDictionary*) uploadHttpHeaders {
    NSString * myPath = nil;
    if (self.localURL != nil) {
        myPath = [[NSURL URLWithString: self.localURL] path];
    } else {
        myPath = @"unknown";
    }
	
    NSString *contentDisposition = [NSString stringWithFormat:@"attachment; filename=\"%@\"", myPath];

    NSDictionary * headers = @{@"Content-Disposition": contentDisposition,
                               @"Content-Type"       : self.mimeType,
                               @"Content-Length" : [self contentSize].stringValue};
    return headers;
}

-(NSDictionary*) downloadHttpHeaders {
    return nil;
}

// http header ranges are inclusive: first 500 bytes are 0-499
-(NSDictionary*) downloadHttpHeadersWithStart:(NSNumber*)start withEnd:(NSNumber*)end {
    NSDictionary * headers = @{@"Range": [NSString stringWithFormat:@"bytes=%@-%@",start, end]};
    return headers;
}

// WARNING: this version depends on remoteURLs to be unique, so is not suitable for remote URLs than are no UUIDs
- (NSURL *) localUrlForDownload {
    /*
    NSURL * myRemoteURL = [NSURL URLWithString: [self remoteURL]];
    NSString * myRemoteFileName = myRemoteURL.lastPathComponent;
    NSURL * myNewFile = [NSURL URLWithString:myRemoteFileName relativeToURL:theDirectory];
     NSString * myNewFilename = [[[myNewFile absoluteString] stringByAppendingString:@"." ] stringByAppendingString: [Attachment fileExtensionFromMimeType: self.mimeType]];
     return myNewFilename;
    */
    
    NSString * fileName = nil;
    if (self.humanReadableFileName != nil && self.humanReadableFileName) {
        fileName = self.humanReadableFileName;
    }
    if (fileName == nil) {
        fileName = NSLocalizedString(self.mediaType, nil);
    }
    
    if (self.mimeType == nil) {
        self.mimeType = @"application/octet-stream";
    }
    NSString * shouldHaveExtension = [Attachment fileExtensionFromMimeType: self.mimeType];
    if (fileName.pathExtension == nil || fileName.pathExtension.length == 0 ) {
        fileName = [fileName stringByAppendingPathExtension:[Attachment fileExtensionFromMimeType: self.mimeType]];
    } else {
        // check if extension is correct
        if (![shouldHaveExtension isEqualToString:fileName.pathExtension]) {
            NSLog(@"Changing extension from file %@", fileName);
            fileName = [fileName stringByDeletingPathExtension];
            fileName = [fileName stringByAppendingPathExtension:shouldHaveExtension];
            NSLog(@"Changing extension to file %@", fileName);
        }
    }
    return [AppDelegate uniqueNewFileURLForFileLike:fileName isTemporary:YES];
}


// fix url when app directory has changed - TODO: only store lastpathcomponent in localRL
- (NSString*) localURL {
    NSString * myPrimitiveLocalURL = [self primitiveValueForKey:@"localURL"];
    NSString * myTranslatedURL = [Attachment translateFileURLToDocumentDirectory:myPrimitiveLocalURL];
    if (URL_TRANSLATION_DEBUG) {
        if (myPrimitiveLocalURL != nil && ![myPrimitiveLocalURL isEqualToString:myTranslatedURL]) {
            NSLog(@"translated localURL from %@ to %@", myPrimitiveLocalURL, myTranslatedURL);
        } else {
            NSLog(@"translated localURLs match");
        }
    }
    return myTranslatedURL;
}

// fix url when app directory has changed - TODO: only store lastpathcomponent in ownedURL
- (NSString*) ownedURL {
    NSString * myPrimitiveLocalURL = [self primitiveValueForKey:@"ownedURL"];
    NSString * myTranslatedURL = [Attachment translateFileURLToDocumentDirectory:myPrimitiveLocalURL];
    if (URL_TRANSLATION_DEBUG) {
        if (myPrimitiveLocalURL != nil && ![myPrimitiveLocalURL isEqualToString:myTranslatedURL]) {
            NSLog(@"translated ownedURL from %@ to %@", myPrimitiveLocalURL, myTranslatedURL);
        } else {
            NSLog(@"translated ownedURL match");
        }
    }
    return myTranslatedURL;
}

- (void) setAspectRatio:(double)newValue {
    [self willChangeValueForKey:@"aspectRatio"];
    [self setPrimitiveValue:@(newValue) forKey:@"aspectRatio"];
    //NSLog(@"aspect ration set to %f", newValue);
    [self didChangeValueForKey:@"aspectRatio"];
    [self.uiDelegate attachmentDidChangeAspectRatio: self];
}

- (double) aspectRatio {
    [self willAccessValueForKey:@"aspectRatio"];
    double myValue = [[self primitiveValueForKey:@"aspectRatio"] doubleValue];
    [self didAccessValueForKey:@"aspectRatio"];
    if (myValue == 0) {
        return 1;
    }
    return myValue;
}

+ (NSString*) translateFileURLToDocumentDirectory:(NSString*)someFileURL {
    if (someFileURL == nil) {
        return nil;
    }
    NSURL * oldURL = [NSURL URLWithString:someFileURL];
    
    NSURL * newDir = AppDelegate.instance.applicationDocumentsDirectory;
    NSArray * pathComponents = [oldURL pathComponents];
    if (pathComponents.count > 2) {
        NSString * dir = pathComponents[pathComponents.count-2];
        if ([AppDelegate.instance.applicationTemporaryDocumentsDirectory.lastPathComponent isEqualToString:dir]) {
            newDir = AppDelegate.instance.applicationTemporaryDocumentsDirectory;
        }
    }
    NSString * myFileName = [someFileURL lastPathComponent];
    NSURL * myLocalURL = [NSURL URLWithString:myFileName relativeToURL:newDir];
    return [myLocalURL absoluteString];
}


+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType {
    if (theMimeType == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(theMimeType), NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    CFRelease(uti);
    NSString * result = CFBridgingRelease(extension);
    if (result == nil) {
        result = [theMimeType lastPathComponent];
    }
    if (result == nil) {
        return @"bin";
    }
    // NSLog(@"fileExtensionFromMimeType result=%@", result);
    return result;
}

+ (NSString *) mimeTypeFromURLExtension: (NSString *) theURLString {
    NSURL * myURL = [NSURL URLWithString: theURLString];
    if ([myURL isFileURL]) {
        return [Attachment mimeTypeFromfileExtension:[myURL pathExtension]];
    } else {
        // NSString * myExtension = [myURL pathExtension];
        // NSLog(@"mimeTypeFromfileURLExtension: Extension from non-file URL: %@ is '%@'", myURL, myExtension);
        return [Attachment mimeTypeFromfileExtension:[myURL pathExtension]];        
    }
    return nil;
}

+ (NSString *) mimeTypeFromfileExtension: (NSString *) theExtension {
    if (theExtension == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(theExtension), NULL);
    CFStringRef mimetype = UTTypeCopyPreferredTagWithClass (uti, kUTTagClassMIMEType);
    CFRelease(uti);
    if (mimetype != nil) {
        return CFBridgingRelease(mimetype);
    } else {
        return @"application/octet-stream";
    }
}

+ (NSString *) mimeTypeFromUTI: (NSString *) uti {
    if (uti == nil) return nil;
    CFStringRef mimetype = UTTypeCopyPreferredTagWithClass ((__bridge CFStringRef)(uti), kUTTagClassMIMEType);
    if (mimetype != nil) {
        return CFBridgingRelease(mimetype);
    } else {
        return @"application/octet-stream";
    }
}

+ (NSString*) UTIfromMimeType:(NSString*)mimeType {
    if (mimeType == nil) return nil;
    if ([mimeType isEqualToString:@"application/octet-stream"]) {
        return @"public.data";
    }
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    return CFBridgingRelease(uti);
}

+ (NSString *) UTIFromfileExtension: (NSString *) theExtension {
    if (theExtension == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(theExtension), NULL);
    if (uti != nil) {
        return CFBridgingRelease(uti);
    } else {
        return @"public.data";
    }
}

+ (NSString*) localizedDescriptionOfUTI:(NSString*)uti {
    if (uti == nil) return nil;
    return CFBridgingRelease(UTTypeCopyDescription((__bridge CFStringRef)(uti)));
}

+ (NSString*) localizedDescriptionOfMimeType:(NSString*)mimeType {
    if (mimeType == nil) return nil;
    return [Attachment localizedDescriptionOfUTI:[Attachment UTIfromMimeType:mimeType]];
}

// connection delegate methods

- (id < NSURLConnectionDelegate >) uploadDelegate {
    return self;
}

- (id < NSURLConnectionDelegate >) downloadDelegate {
    return self;
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == _transferConnection) {
        if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection didReceiveResponse %@, status=%ld, %@, headers=%@",httpResponse, (long)[httpResponse statusCode],[NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]], [httpResponse allHeaderFields]);}
        self.transferHttpStatusCode = (long)[httpResponse statusCode];
        if (self.transferHttpStatusCode != 200 && self.transferHttpStatusCode != 206 ) {
            if (transferHttpStatusCode >= 400) {
                if (transferHttpStatusCode == 404) {
                    int maxRetries = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentDownloadRetries] intValue];
                    NSLog(@"Attachment:transferConnection:didReceiveResponse 404, setting retry counter to maxRetries = %d", maxRetries);
                    self.transferFailures = maxRetries;
                }
                
                self.transferConnection = nil; // make sure we do not get any more data
                if (CONNECTION_TRACE) {NSLog(@"### did set transferConnection to nil to avoid receiving data");}
                // NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
                // [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
            }
            
            // TODO: check if this is necessary and leads to duplicate error reporting
            NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection didReceiveResponse http status code =%ld", self.transferHttpStatusCode];
            if (CONNECTION_TRACE) {NSLog(@"%@", myDescription);}
            self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 667 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            if (self.outgoing) {
                [self.chatBackend uploadFailed:self];
            } else {
                [self.chatBackend downloadFailed:self];
            }
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveResponse without valid connection");        
    }
}


+(NSError*) appendToFile:(NSString*)fileURL thisData:(NSData *) data {
    NSURL * myURL = [NSURL URLWithString: fileURL];
    NSString * myPath = [myURL path];
    NSOutputStream * stream = [[NSOutputStream alloc] initToFileAtPath: myPath append:YES];
    if (stream.streamError != nil) {
        NSLog(@"#ERROR: appendToFile: init failed, error=%@", stream.streamError);
        return stream.streamError;
    }
    [stream open];
    if (stream.streamError != nil) {
        NSLog(@"#ERROR: appendToFile: open failed, error=%@", stream.streamError);
        return stream.streamError;
    }
    NSUInteger left = [data length];
    NSUInteger nwr = 0;
    do {
        nwr = [stream write:[data bytes] maxLength:left];
        if (stream.streamError != nil) {
            NSLog(@"#ERROR: appendToFile: write failed, error=%@", stream.streamError);
            [stream close];
            return stream.streamError;
        }
        if (-1 == nwr) break;
        left -= nwr;
    } while (left > 0);
    if (left) {
        [stream close];
        NSLog(@"ERROR: Attachment could not write all bytes, stream error: %@", [stream streamError]);
    }
    [stream close];
    if (stream.streamError != nil) {
        NSLog(@"#ERROR: appendToFile: close failed, error=%@", stream.streamError);
        return stream.streamError;
    }
    return nil;
}

+(NSError*) appendToFilePosix:(NSString*)fileURL thisData:(NSData *) data {
    NSURL * myURL = [NSURL URLWithString: fileURL];
    return [self appendToFileURLPosix:myURL thisData:data];
}

+(NSError*) createFileAtURLPosix:(NSURL*)myURL {
    NSError * myError = nil;
    NSString * myPath = [myURL path];
    int fd = open([myPath UTF8String], O_WRONLY|O_APPEND|O_EXLOCK|O_CREAT,0777);
    if (fd != -1) {
        NSInteger result2 = close(fd);
        if (result2 == -1) {
            NSString * myDescription = [NSString stringWithFormat:@"Attachment createFileAtURLPosix close failed, errno=%d", errno];
            NSLog(@"%@", myDescription);
            myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 662 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            return myError;
        }
    } else {
        NSString * myDescription = [NSString stringWithFormat:@"Attachment createFileAtURLPosix open failed, errno=%d, path=%s", errno,[myPath UTF8String]];
        NSLog(@"%@", myDescription);
        myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 660 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return myError;
        
    }
    return nil;
}


+(NSError*) appendToFileURLPosix:(NSURL*)myURL thisData:(NSData *) data {
    NSError * myError = nil;
    NSString * myPath = [myURL path];
    int fd = open([myPath UTF8String], O_WRONLY|O_APPEND|O_EXLOCK|O_CREAT,0777);
    if (fd == -1) {
        unlink([myPath UTF8String]);
        NSString * myDescription = [NSString stringWithFormat:@"Attachment appendToFile open failed, errno=%d, path=%s", errno,[myPath UTF8String]];
        NSLog(@"%@", myDescription);
        myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 660 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return myError;
    }
    
    NSUInteger left = [data length];
    NSUInteger nwr = 0;
    do {
        nwr = write(fd,[data bytes],left);
        if (-1 == nwr) break;
        left -= nwr;
    } while (left > 0);
    if (left) {
        NSString * myDescription = [NSString stringWithFormat:@"Attachment appendToFile write failed, errno=%d", errno];
        NSLog(@"%@", myDescription);
        myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 661 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        close(fd);
        return myError;
    }
    NSInteger result = fsync(fd);
    if (result == -1) {
        NSString * myDescription = [NSString stringWithFormat:@"Attachment appendToFile fsync failed, errno=%d", errno];
        NSLog(@"%@", myDescription);
        myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 662 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        close(fd);
        return myError;
    }
    NSInteger result2 = close(fd);
    if (result2 == -1) {
        NSString * myDescription = [NSString stringWithFormat:@"Attachment appendToFile close failed, errno=%d", errno];
        NSLog(@"%@", myDescription);
        myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment.io" code: 662 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        return myError;
    }
    return nil;
}

+ (NSData*)readDataFromFileAtURL:(NSURL*)url atOffset:(off_t)start withSize:(off_t) length {
    NSString * myPath = [url path];
    return [Attachment readDataFromFileAtPath:myPath atOffset:start withSize:length];
}

+ (NSData*)readDataFromFileAtFileURLString:(NSString*)fileUrl atOffset:(off_t)start withSize:(off_t) length {
    NSURL * myURL = [NSURL URLWithString: fileUrl];
    return [Attachment readDataFromFileAtURL:myURL atOffset:start withSize:length];
}


+ (NSData*)readDataFromFileAtPath:(NSString*)filePath atOffset:(off_t)start withSize:(off_t) length {
        
    int fd = open([filePath UTF8String], O_RDONLY);
    
    if (fd == -1) {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, open failed, error=%d", errno);
        return nil;
    }
    
    off_t pos = lseek(fd, start, SEEK_SET);
    if (pos != start) {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, seek to %lld returned %lld, error=%d", start, pos, errno);
        close(fd);
        return nil;
    }
    
    NSMutableData* theData = [[NSMutableData alloc] initWithLength:length];
    
    if (theData) {
        void* buffer = [theData mutableBytes];
        NSUInteger bufferSize = [theData length];
        off_t actualBytes = read(fd, buffer, bufferSize);
        if (actualBytes < length) {
            NSLog(@"ERROR: Attachment readDataFromFileAtPath, wanted %lld bytes, got only %lld", length, actualBytes);
            theData = nil;
        }
    } else {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, could not allocate NSData with len=%lld", length);
    }
    close(fd);
    
    return theData;
}

+ (void)truncateFileAtPath:(NSString*)filePath toSize:(off_t) length {
    if (truncate([filePath UTF8String], length) != 0) {
        NSLog(@"Attachment: truncateFileAtPath: %@ toSize: %lld failed, errno=%d", filePath, length, errno);
    }
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.chatBackend connection:connection willSendRequestForAuthenticationChallenge:challenge];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _transferConnection) {
        if (TRANSFER_TRACE) {NSLog(@"Attachment transferConnection didReceiveData len=%u", (int)[data length]);}
        if (self.incoming) {
            NSError *myError = nil;
            if (self.resumePos != 0) {
                off_t myFileSize = [[Attachment fileSize:self.ownedURL withError:&myError] unsignedLongLongValue];
                if (self.resumePos != myFileSize || self.decryptionEngine != nil) {
                    NSLog(@"ERROR: didReceiveData: can not resume; resumePos/fileSze mismatch or self.decryptionEngine!=nil; resumePos=%@ fileSize=%lld, decryptionEngine=%@, error=%@", @(self.resumePos), myFileSize, self.decryptionEngine, myError);
                    return;
                } else {
                    // resume
                    if (data.length < 16) {
                        NSLog(@"ERROR: didReceiveData: can not resume, first data chunk < 16 bytes, chunk size = %@", @(data.length));
                        return;
                    }
                    // set up crypto engine
                    NSData * messageKey = self.message.cryptoKey;
                    NSError * myError = nil;
                    NSData * iv = [data subdataWithRange:NSMakeRange(0,16)];
                    
                    self.decryptionEngine = [[CryptoEngine alloc]
                                             initWithOperation:kCCDecrypt
                                             algorithm:kCCAlgorithmAES128
                                             options:kCCOptionPKCS7Padding
                                             key:messageKey
                                             IV:iv
                                             error:&myError];
                    
                    if (CONNECTION_TRACE) {NSLog(@"response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);}
                    
                    data = [data subdataWithRange:NSMakeRange(16, data.length-16)];
                    if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection didReceiveData: resume crypto setup done, restlen=%@", @(data.length));}
#ifdef LET_DOWNLOAD_FAIL
                    self.didResume = YES;
#endif
                    self.resumePos = 0;
                }
            }
            NSData * plainTextData = [self.decryptionEngine addData:data error:&myError];
            if (myError != nil) {
                NSLog(@"ERROR: didReceiveData: decryption error: %@",myError);
                return;
            }
            myError = [Attachment appendToFilePosix:self.ownedURL thisData:plainTextData];
            if (myError != nil) {
                NSLog(@"Attachment didReceiveData: appending to file failed, error=%@", myError);
                [connection cancel];
                return;
            };
            
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];
            self.cipherTransferSize = [NSNumber numberWithLong:[self.cipherTransferSize longLongValue]+ data.length];
            [self notifyTransferProgress: [self.transferSize floatValue] / [self.contentSize floatValue]];
#ifdef LET_DOWNLOAD_FAIL
            /// DEBUG: abort artificially
            NSInteger limit = [self.cipheredSize unsignedLongValue] - self.resumeSize/2 + 1000;
            // NSLog(@"TEST: didReceiveData: cancel limit=%d, cipherTransferSize=%@, self.resumeSize=%d",limit, self.cipherTransferSize, self.resumeSize);
            if ([self.cipherTransferSize longValue]< [self.cipheredSize longValue] && [self.cipherTransferSize unsignedLongValue] > limit) { // fail multiple times
                // if (!didResume && [self.cipherTransferSize unsignedLongValue] > [self.cipheredSize unsignedLongValue]/2) { // fail once
                [_transferConnection cancel];
                _transferConnection = nil;
                NSLog(@"TEST: didReceiveData: canceling transfer, cipherTransferSize=%@, cipheredSize=%@",self.cipherTransferSize,self.cipheredSize);
                [self.chatBackend downloadFailed:self];
                return;
            }
#endif
        } else {
            NSLog(@"ERROR: Attachment transferConnection didReceiveData on outgoing (upload) connection");
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == _transferConnection) {
        if (TRANSFER_TRACE) {NSLog(@"Attachment transferConnection didSendBodyData %lld", (off_t)bytesWritten);}
        //self.cipherTransferSize = @(totalBytesWritten);
        self.cipherTransferSize = @([self.cipherTransferSize integerValue]+bytesWritten);
#ifdef LET_UPLOAD_FAIL
        /// DEBUG: abort artificially
        //if (!didResume && [self.cipherTransferSize unsignedLongValue] > [self.cipheredSize unsignedLongValue]/3) { // fail once
        NSInteger limit = [self.cipheredSize unsignedLongValue] - totalBytesExpectedToWrite/2 + 1000;
        // NSLog(@"TEST: didSendBodyData: cancel limit=%d, cipherTransferSize=%@, totalBytesExpectedToWrite=%d",limit, self.cipherTransferSize, totalBytesExpectedToWrite);
        if ([self.cipherTransferSize longValue] < [self.cipheredSize longValue] && [self.cipherTransferSize unsignedLongValue] > limit) { // fail multiple times
            NSLog(@"TEST: didSendBodyData: canceling transfer at size %@, limit=%d",self.cipherTransferSize, limit);
            // abort();
            [_transferConnection cancel];
            _transferConnection = nil;
            [self.chatBackend uploadFailed:self];
            self.transferFailures = 1;
            return;
        }
#endif
        [self notifyTransferProgress: [self.cipherTransferSize floatValue] / [self.cipheredSize floatValue]];
    } else {
        NSLog(@"ERROR: Attachment transferConnection didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == _transferConnection) {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError %@, url=%@", error, self.remoteURL);
        self.transferConnection = nil;
        self.transferError = error;
        [self notifyTransferFinished];
        if (self.outgoing) {
            [self.chatBackend uploadFailed:self];
        } else {
            [self.chatBackend downloadFailed:self];
        }
        [self unregisterBackgroundTask];
    } else {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError without valid connection");
    }
}
    
-(void) trySaveToAlbum {
    if ([self.mediaType isEqualToString: @"image"]) {
        [self loadImageAttachmentImage: ^(UIImage* image, NSError* error) {
            // NSLog(@"saveMessage: loadImageAttachmentImage done");
            if (image) {
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        // NSLog(@"Saved image to Library");
                    } else {
                        NSLog(@"trySaveToAlbum: Error saving image in Library, error = %@", error);
                        [HXOUI showErrorAlertWithMessage:[error localizedDescription] withTitle: @"attachment_save_to_album_failed_title"];
                    }
                };
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeImageToSavedPhotosAlbum:[image CGImage]
                                          orientation:(ALAssetOrientation)[image imageOrientation]
                                      completionBlock:completeBlock];
            } else {
                [HXOUI showErrorAlertWithMessage:[error localizedDescription] withTitle: @"attachment_save_to_album_failed_title"];
                NSLog(@"trySaveToAlbum: Failed to get image: %@", error);
            }
        }];
        return;
    }
    if ([self.mediaType isEqualToString: @"video"]) {
        NSString * myVideoFilePath = [[NSURL URLWithString: self.localURL] path];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(myVideoFilePath)) {
            UISaveVideoAtPathToSavedPhotosAlbum(myVideoFilePath, nil, nil, nil);
            NSLog(@"trySaveToAlbum: saved video in album at path = %@",myVideoFilePath);
        } else {
            NSLog(@"trySaveToAlbum: failed to save video in album at path = %@",myVideoFilePath);
            [HXOUI showErrorAlertWithMessage:@"attachment_incompatible_video_message" withTitle: @"attachment_save_to_album_failed_title"];
        }
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _transferConnection) {
        if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection connectionDidFinishLoading %@", connection);}
        self.transferConnection = nil;

        if (self.incoming) {
            // finish download
            NSError *myError = nil;
            NSData * plainTextData = [self.decryptionEngine finishWithError:&myError];
            if (myError != nil) {
                NSLog(@"connectionDidFinishLoading: decryption error: %@",myError);
                [self.chatBackend downloadFailed:self];
                [self unregisterBackgroundTask];
               return;
            }
            myError = [Attachment appendToFilePosix:self.ownedURL thisData:plainTextData];
            if (myError != nil) {
                NSLog(@"Attachment connectionDidFinishLoading: appending to file failed, error=%@", myError);
                [connection cancel];
                [self.chatBackend downloadFailed:self];
                [self unregisterBackgroundTask];
                return;
            };
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];

            if ([self.transferSize isEqualToNumber: self.contentSize]) {
                if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully downloaded attachment, size=%@", self.contentSize);}
                self.ownedURL = [[AppDelegate moveDocumentToPermanentLocation:[NSURL URLWithString:self.ownedURL]] absoluteString];
                self.localURL = self.ownedURL;
                [self computeDestMac];
                [self determinePlayability];
                [self.chatBackend downloadFinished:self];
                if ([[[HXOUserDefaults standardUserDefaults] objectForKey:@"autoSaveMedia"] boolValue]) {
                    [self trySaveToAlbum];
                }
            } else {
                NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection connectionDidFinishLoading download failed, contentSize=%@, self.transferSize=%@", self.contentSize, self.transferSize];
                NSLog(@"%@", myDescription);
                self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 667 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                [self.chatBackend downloadFailed:self];
            }
        } else {
            // upload finished
            if ([self.cipheredSize isEqualToNumber:self.cipherTransferSize]) {
                self.transferSize = self.contentSize;
                if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully uploaded attachment, size=%@", self.contentSize);}
                [self.chatBackend uploadFinished:self];
            } else {
                NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection connectionDidFinishLoading size mismatch, cipheredSize=%@, cipherTransferSize=%@", self.cipheredSize, self.cipherTransferSize];
                NSLog(@"%@", myDescription);
                self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 666 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                [self.chatBackend uploadFailed:self];
            }
        }
        [self unregisterBackgroundTask];
        [self notifyTransferFinished];
    } else {
        NSLog(@"ERROR: Attachment transferConnection connectionDidFinishLoading without valid connection");
    }
}

- (void) determinePlayability {
    if ([self.mediaType isEqualToString:@"audio"] && self.contentURL) {
        AVURLAsset *asset = [AVURLAsset assetWithURL:self.contentURL];
        self.playable = asset.playable ? @"YES" : @"NO";
        NSLog(@"asset %@ playable:%@", self.contentURL, self.playable);
    }
}

- (void) registerBackgroundTask {
    NSLog(@"Attachment: registering background task...");
    
    if (_backgroundTaskId != UIBackgroundTaskInvalid) {
        NSLog(@"#WARNING: Attachment: trying to registering background task while one is already registered");
    }

    UIApplication *app = [UIApplication sharedApplication];
    [AppDelegate.instance startedBackgroundTask];
    _backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler: ^{
        NSLog(@"##WARNING: Attachment: runnung background task expiration handler...");
       if (self.transferRetryTimer != nil) {
            [self.transferRetryTimer invalidate];
            self.transferRetryTimer = nil;
        }
        if (self.transferConnection != nil) {
            [self.transferConnection cancel];
            self.transferConnection = nil;
            [(AppDelegate*)app.delegate saveDatabase];
        }
        [AppDelegate.instance finishedBackgroundTask];
        [app endBackgroundTask:_backgroundTaskId];
        _backgroundTaskId = UIBackgroundTaskInvalid;
    }];
}

- (void) unregisterBackgroundTask {
    NSLog(@"Attachment: unregistering background task...");
    [AppDelegate.instance finishedBackgroundTask];
    UIApplication *app = [UIApplication sharedApplication];
    [app endBackgroundTask:_backgroundTaskId];
    _backgroundTaskId = UIBackgroundTaskInvalid;
}

#pragma mark - Custom Getters and Setters

- (void) setContentSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"contentSize"];
    [self setPrimitiveValue: size forKey: @"contentSize"];
    [self didChangeValueForKey:@"contentSize"];
}

- (void) setTransferSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"transferSize"];
    [self setPrimitiveValue: size forKey: @"transferSize"];
    [self didChangeValueForKey:@"transferSize"];
}

- (void) setCipherTransferSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"cipherTransferSize"];
    [self setPrimitiveValue: size forKey: @"cipherTransferSize"];
    [self didChangeValueForKey:@"cipherTransferSize"];
}

- (void) setCipheredSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"cipheredSize"];
    [self setPrimitiveValue: size forKey: @"cipheredSize"];
    [self didChangeValueForKey:@"cipheredSize"];
}


#pragma mark - Attachment JSON Wrapping

- (NSDictionary*) JsonKeys {
    return @{
             @"url": @"remoteURL",
             @"contentSize": @"contentSize",
             @"mediaType": @"mediaType",
             @"mimeType": @"mimeType",
             @"aspectRatio": @"aspectRatio",
             @"fileName": @"humanReadableFileName",
             @"hmac": @"sourceMACString"
             };
}

- (NSString*) attachmentJsonString {
    NSDictionary * myRepresentation = [HXOModel createDictionaryFromObject:self withKeys:self.JsonKeys];
    NSData * myJsonData = [NSJSONSerialization dataWithJSONObject: myRepresentation options: 0 error: nil];
    NSString * myJsonUTF8String = [[NSString alloc] initWithData:myJsonData encoding:NSUTF8StringEncoding];
    // NSLog(@"attachmentJsonString=%@",myJsonUTF8String);
    // NSLog(@"%@", [NSThread callStackSymbols]);
    return myJsonUTF8String;
}

//static const NSInteger kJsonRpcAttachmentParseError  = -32700;

-  (void) setAttachmentJsonString:(NSString*) theJsonString {
    NSError * error;
    @try {
        id json = [NSJSONSerialization JSONObjectWithData: [theJsonString dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
        if (json == nil) {
            NSLog(@"ERROR: setAttachmentJsonString: JSON parse error: %@ on string %@", error.userInfo[@"NSDebugDescription"], theJsonString);
            return;
        }
        //NSLog(@"attachment=%@",json);
        if ([json isKindOfClass: [NSDictionary class]]) {
            NSMutableDictionary * backwardsCompatibleJsonKeys = [NSMutableDictionary dictionaryWithDictionary: [self JsonKeys]];
            [backwardsCompatibleJsonKeys setObject: backwardsCompatibleJsonKeys[@"fileName"] forKey: @"filename"];
            [HXOModel updateObject:self withDictionary:json withKeys: backwardsCompatibleJsonKeys];
        } else {
            NSLog(@"ERROR: attachment json not encoded as dictionary, json string = %@", theJsonString);
        }
    } @catch (NSException * ex) {
        NSLog(@"ERROR: setAttachmentJsonString: parsing json, jsonData = %@, ex=%@", theJsonString, ex);
    }
}

- (NSString*) sourceMACString {
    return [self.sourceMAC asBase64EncodedString];
}

-(void) setSourceMACString:(NSString *)theB64String {
    self.sourceMAC = [NSData dataWithBase64EncodedString:theB64String];
}

- (NSString*) attachmentJsonStringCipherText {
    return [self.message encryptString: self.attachmentJsonString];
}

-(void) setAttachmentJsonStringCipherText:(NSString*) theB64String {
    self.attachmentJsonString = [self.message decryptString:theB64String];
}

- (void) willTurnIntoFault {
    self.previewImage = nil; // purge from image cache
    if (TRACE_ATTACHMENT_FAULTING) NSLog(@"attachment will turn into fault: %@", self.humanReadableFileName);
}

- (void) prepareForDeletion {
    if (TRACE_ATTACHMENT_DELETION) NSLog(@"Attachment: prepareForDeletion: contentURL %@ ownedURL %@", self.contentURL, self.ownedURL);
    [super prepareForDeletion];
    if (![AppDelegate.instance.currentObjectContext isEqual:AppDelegate.instance.mainObjectContext]) {
        if (TRACE_ATTACHMENT_DELETION) NSLog(@"Attachment: prepareForDeletion: not in main context, doing nothing");
        return;
    }
    
    self.previewImage = nil; // purge from image cache
    
    // cancel a potential open transferconnection
    if (self.transferConnection != nil) {
        [self.transferConnection cancel];
        self.transferConnection = nil;
    }
    
    // invalidate a potential retry timer
    if (self.transferRetryTimer != nil) {
        [self.transferRetryTimer invalidate];
        self.transferRetryTimer = nil;
    }
    
    // remove associated media file if not referenced by other attachments
    if (self.ownedURL != nil && self.ownedURL.length > 0) {
        NSURL * myURL = [NSURL URLWithString:self.ownedURL];
        if (TRACE_ATTACHMENT_DELETION) NSLog(@"Deleting ownedURL %@", myURL);
        [Attachment deleteFileAtUrl:myURL];
        /*
        AppDelegate * delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        NSError *error;
        NSDictionary * vars = @{ @"ownedURL" : self.ownedURL};
        NSFetchRequest *fetchRequest = [delegate.managedObjectModel fetchRequestFromTemplateWithName:@"AttachmentsByOwnedURL" substitutionVariables: vars];
        NSArray *attachments = [delegate.currentObjectContext executeFetchRequest:fetchRequest error:&error];
        if (attachments == nil) {
            NSLog(@"Fetch request failed: %@", error);
            abort();
        }
        if (TRACE_ATTACHMENT_DELETION) NSLog(@"Found %lu attachments referenced by ownedURL %@", attachments.count, self.ownedURL);
        
        // the fetch request will not return the attachment being deleted
        
        if (attachments.count == 0) {
            // delete ownedURL because it is only referenced by one message
            if (TRACE_ATTACHMENT_DELETION) NSLog(@"Deleting ownedURL %@, not referenced by other messages", self.ownedURL);
            NSURL * myURL = [NSURL URLWithString:self.ownedURL];
            [Attachment deleteFileAtUrl:myURL];
        } else {
            if (TRACE_ATTACHMENT_DELETION) NSLog(@"Keeping ownedURL %@, is referenced by other messages", self.ownedURL);
        }
         */
    } else {
        if (TRACE_ATTACHMENT_DELETION) NSLog(@"File has no ownedURL, not deleting local URL %@", self.localURL);
    }

    // remove from transfer queues
    [self.chatBackend dequeueDownloadOfAttachment:self];
    [self.chatBackend dequeueUploadOfAttachment:self];
    
    // remove attachment from collections
    /* I think this is exactly a 'cascade' delete rule. I'll disable it and set
     * the delete rule accordingly...
    for (CollectionItem *item in self.collectionItems) {
        [item.collection removeItemAtIndex:item.index];
    }
    */
}

+(BOOL)deleteFileAtUrl:(NSURL*)myURL {
    BOOL result = NO;
    if ([myURL isFileURL]) {
        NSError * myError = nil;
        [[NSFileManager defaultManager] removeItemAtURL:myURL error:&myError];
        if (myError != nil) {
            NSLog(@"#ERROR: could not delete file at URL %@, error = %@", myURL, myError);
        } else {
            NSLog(@"Deleted file at URL %@", myURL);
            result = YES;
        }
        NSURL * metaURL = [AppDelegate metaDataURL:myURL];
        if (metaURL != nil) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:[metaURL path]]) {
                NSError * myError = nil;
                [[NSFileManager defaultManager] removeItemAtURL:metaURL error:&myError];
                if (myError != nil) {
                    NSLog(@"#ERROR: could not delete metadata file at URL %@, error = %@", metaURL, myError);
                } else {
                    if (TRACE_ATTACHMENT_DELETION) NSLog(@"Deleted metadata file at URL %@", metaURL);
                }
            } else {
                if (TRACE_ATTACHMENT_DELETION) NSLog(@"No metadata file at URL %@", metaURL);
            }
        }
    }
    return result;
}


- (void) notifyTransferScheduled {
    if (uiDelegate) {
        [uiDelegate attachmentTransferScheduled: self];
    } else {
        if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"no delegate for attachmentTransferScheduled");}
    }
}

- (void) notifyTransferStarted {
    if (uiDelegate) {
        [uiDelegate attachmentTransferStarted: self];
    } else {
        if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"no delegate for attachmentTransferStarted");}
    }
}

- (void) notifyTransferFinished {
    if (uiDelegate) {
        [uiDelegate attachmentTransferFinished: self];
    } else {
        NSLog(@"no delegate to signal attachmentTransferFinished");
    }
}

- (void) notifyTransferProgress: (CGFloat) progress {
    if (uiDelegate) {
        [uiDelegate attachment: self transferDidProgress: progress];
    } else {
        if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"no delegate for transferDidProgress");}
    }
}


#pragma mark - Attachment UIActivityItemSource Protocol

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType {
    NSLog(@"dataTypeIdentifierForActivityType %@ = %@",activityType, [Attachment UTIfromMimeType:self.mimeType]);
    return [Attachment UTIfromMimeType:self.mimeType];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    NSLog(@"itemForActivityType %@ = %@",activityType, self.contentURL);
    return self.contentURL;
}
/*
 - (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType {
 
 }
 
 - (UIImage *)activityViewController:(UIActivityViewController *)activityViewController thumbnailImageForActivityType:(NSString *)activityType suggestedSize:(CGSize)size {
 
 }
 */
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    NSLog(@"activityViewControllerPlaceholderItem %@", self.contentURL);
    return self.contentURL;
}

#pragma mark - Clone

- (Attachment *) clone {
    Attachment *attachment = [NSEntityDescription insertNewObjectForEntityForName:[[self class] entityName] inManagedObjectContext:self.managedObjectContext];
    
    attachment.mediaType = self.mediaType;
    attachment.mimeType = self.mimeType;
    attachment.humanReadableFileName = self.humanReadableFileName;
    attachment.ownedURL = self.ownedURL;
    attachment.aspectRatio = self.aspectRatio;
    
    [attachment useURLs:self.localURL anOtherURL:self.assetURL];
    
    return attachment;
}

- (Attachment*) cloneWithCompletion:(AttachmentCompletionBlock)attachmentCompleted {
    Attachment * attachment = self;
    Attachment * newAttachment = nil;
    if (attachment) {
        newAttachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: [AppDelegate instance].currentObjectContext];
        
        newAttachment.mediaType = attachment.mediaType;
        newAttachment.mimeType = attachment.mimeType;
        newAttachment.humanReadableFileName = attachment.humanReadableFileName;
        newAttachment.aspectRatio = attachment.aspectRatio;
        
        CompletionBlock completion  = ^(NSError *myerror) {
            attachmentCompleted(newAttachment, myerror);
        };
        
        if ([newAttachment.mediaType isEqualToString:@"image"]) {
            [newAttachment makeImageAttachment: attachment.localURL anOtherURL:attachment.assetURL image:nil withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"video"]) {
            [newAttachment makeVideoAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"audio"]) {
            [newAttachment makeAudioAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"vcard"]) {
            [newAttachment makeVcardAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"geolocation"]) {
            [newAttachment makeGeoLocationAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        } else if ([newAttachment.mediaType isEqualToString:@"data"]) {
            [newAttachment makeDataAttachment: attachment.localURL anOtherURL:attachment.assetURL withCompletion:completion];
        }
    }
    return newAttachment;
}



+ (Attachment*) makeAttachmentWithMediaType:(NSString*)mediaType
                                   mimeType:(NSString*)mimeType
                      humanReadableFileName:(NSString*)humanReadableFileName
                                   localURL:(NSString*)localURL
                                   assetURL:(NSString*)assetURL
                                  inContext:(NSManagedObjectContext*)context
                                  whenReady:(AttachmentCompletionBlock)attachmentCompleted
{
    Attachment * newAttachment = [NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: context];
    [newAttachment initAttachmentWithMediaType:mediaType mimeType:mimeType humanReadableFileName:humanReadableFileName localURL:localURL assetURL:assetURL inContext:context whenReady:attachmentCompleted];
    return  newAttachment;
    
}

- (void) reinitializeInContext:(NSManagedObjectContext*)context
                     whenReady:(AttachmentCompletionBlock)attachmentCompleted {
    
    [self initAttachmentWithMediaType:self.mediaType mimeType:self.mimeType humanReadableFileName:self.humanReadableFileName localURL:self.localURL assetURL:self.assetURL inContext:context whenReady:attachmentCompleted];
    
}

- (void) initAttachmentWithMediaType:(NSString*)mediaType
                                   mimeType:(NSString*)mimeType
                      humanReadableFileName:(NSString*)humanReadableFileName
                                   localURL:(NSString*)localURL
                                   assetURL:(NSString*)assetURL
                                  inContext:(NSManagedObjectContext*)context
                                  whenReady:(AttachmentCompletionBlock)attachmentCompleted
{
    Attachment * newAttachment = self;
    
    newAttachment.mediaType = mediaType;
    newAttachment.mimeType = mimeType;
    newAttachment.humanReadableFileName = humanReadableFileName;
    
    CompletionBlock completion  = ^(NSError *myerror) {
        attachmentCompleted(newAttachment, myerror);
    };
    
    if ([newAttachment.mediaType isEqualToString:@"image"]) {
        [newAttachment makeImageAttachment: localURL anOtherURL:assetURL image:nil withCompletion:completion];
    } else if ([newAttachment.mediaType isEqualToString:@"video"]) {
        [newAttachment makeVideoAttachment: localURL anOtherURL:assetURL withCompletion:completion];
    } else if ([newAttachment.mediaType isEqualToString:@"audio"]) {
        [newAttachment makeAudioAttachment: localURL anOtherURL:assetURL withCompletion:completion];
    } else if ([newAttachment.mediaType isEqualToString:@"vcard"]) {
        [newAttachment makeVcardAttachment: localURL anOtherURL:assetURL withCompletion:completion];
    } else if ([newAttachment.mediaType isEqualToString:@"geolocation"]) {
        [newAttachment makeGeoLocationAttachment: localURL anOtherURL:assetURL withCompletion:completion];
    } else if ([newAttachment.mediaType isEqualToString:@"data"]) {
        [newAttachment makeDataAttachment:localURL anOtherURL:assetURL withCompletion:completion];
    }
}


- (void)performSafeDeletion {
    [AppDelegate.instance saveContext];
    NSManagedObjectID * currentAttachmentId = self.objectID;
    [AppDelegate.instance performWithLockingId:@"Attachments" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        Attachment * currentAttachment = (Attachment*)[context objectWithID:currentAttachmentId];
        [AppDelegate.instance deleteObject:currentAttachment inContext:context];
    }];
}


@end
