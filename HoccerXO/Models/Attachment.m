//
//  Attachment.m
//  HoccerXO
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "HXOMessage.h"
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

#import "NSData+Base64.h"

#import "NSString+StringWithData.h"

#import <Foundation/NSURL.h>
#import <MediaPlayer/MPMoviePlayerController.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVFoundation.h>
#import <AddressBookUI/AddressBookUI.h>

#define TRANSFER_TRACE ([[self verbosityLevel]isEqualToString:@"moretrace"])
#define CONNECTION_TRACE ([[self verbosityLevel]isEqualToString:@"trace"] || TRANSFER_TRACE)

#define CONNECTION_DELEGATE_DEBUG NO
#define URL_TRANSLATION_DEBUG NO

//#define LET_UPLOAD_FAIL
//#define LET_DOWNLOAD_FAIL

//#define NO_DOWNLOAD_RESUME
//#define NO_UPLOAD_RESUME


@interface Attachment() {
    
}
#if defined(LET_DOWNLOAD_FAIL) || defined(NO_DOWNLOAD_RESUME) || defined(NO_UPLOAD_RESUME)
@property BOOL didResume;
@property NSInteger resumeSize;
#endif

@end

@implementation Attachment
{
    NSString * _verbosityLevel;
    NSError * _transferError;
    UIBackgroundTaskIdentifier _backgroundTaskId;
}

@dynamic localURL;
@dynamic mimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic contentSize;
@dynamic aspectRatio;

@dynamic remoteURL;
@dynamic uploadURL;

@dynamic transferSize;
@dynamic cipherTransferSize;
@dynamic cipheredSize;
@dynamic transferFailures;
@dynamic previewImageData;

@dynamic message;

@dynamic transferFailed;
@dynamic transferPaused;
@dynamic transferAborted;

@dynamic attachmentJsonString;
@dynamic attachmentJsonStringCipherText;

@dynamic state;

@synthesize transferConnection = _transferConnection;
@synthesize transferError = _transferError;
@synthesize transferHttpStatusCode;
@synthesize chatBackend = _chatBackend;
@synthesize previewImage = _previewImage;
@synthesize progressIndicatorDelegate;
@synthesize decryptionEngine;
@synthesize encryptionEngine;
@synthesize transferRetryTimer = _transferRetryTimer;
@synthesize resumePos;

#if defined(LET_DOWNLOAD_FAIL) || defined(NO_DOWNLOAD_RESUME) || defined(NO_UPLOAD_RESUME)
@synthesize didResume; // DEBUG
@synthesize resumeSize; // DEBUG
#endif

- (void) setTransferRetryTimer:(NSTimer*) theTimer {
    if (theTimer.isValid) {
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferScheduled];
        } else {
            if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"Attachment:uploadData - no delegate for transferStarted");}
        }
    }
    _transferRetryTimer = theTimer;
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
    if (self.message == nil) {
        return kAttachmentDetached;
    }
    if (self.contentSize == nil || [self.contentSize isEqualToNumber:@(0)]) {
        return kAttachmentEmpty;
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
        if ([self.message.isOutgoing boolValue] == YES) {
            return kAttachmentUploadIncomplete;
        }
        return kAttachmentDownloadIncomplete;
    }
    // now check limits
    if ([self.message.isOutgoing boolValue]) {
        long long uploadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoUploadLimit] longLongValue];
        if (uploadLimit && [self.contentSize longLongValue] > uploadLimit) {
            return kAttachmentTransferOnHold;
        }
    } else {
        // incoming
        long long downloadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoDownloadLimit] longLongValue];
        if (downloadLimit && [self.contentSize longLongValue] > downloadLimit) {
            return kAttachmentTransferOnHold;
        }
    }
    return kAttachmentWantsTransfer;
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
        // NSLog(@"File Size = %@ (of file '%@')", self.contentSize, self.localURL);
    } else if (self.assetURL != nil) {
        [self assetSizer:^(int64_t theSize, NSError * theError) {
            self.contentSize = @(theSize);
            // NSLog(@"Asset Size = %@ (of file '%@')", self.contentSize, self.assetURL);
        } url:self.assetURL];
    } else {
        NSLog(@"ERROR: both urls are nil, could not determine content size");
    }
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
    } else {
        NSLog(@"WARNING - Attachment loadImage: unhandled attachment type %@", self.mediaType);
    }
}


- (void) setPreviewImageFromImage:(UIImage*) theFullImage {
    float previewWidth = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOPreviewImageWidth] floatValue];
    if (previewWidth > theFullImage.size.width) {
        previewWidth = theFullImage.size.width; // avoid scaling up preview
    }
    if (!(self.aspectRatio > 0)) {
        [self setAspectRatioForImage:theFullImage];
    }
    self.previewImage = [theFullImage imageScaledToSize:CGSizeMake(previewWidth, previewWidth/self.aspectRatio)];

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
    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
    self.previewImageData = UIImageJPEGRepresentation(self.previewImage, photoQualityCompressionSetting/10.0);
#endif
}

- (void) setAspectRatioForImage:(UIImage*) theImage {
    self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
}

- (void) loadPreviewImageIntoCacheWithCompletion:(CompletionBlock)finished {
    // NSLog(@"loadPreviewImageIntoCacheWithCompletion");
    if (self.previewImageData != nil && self.previewImageData.length > 0) {
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database");
        // NSDate * start = [NSDate date];
        self.previewImage = [UIImage imageWithData:self.previewImageData];
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database took %f ms.", -[start timeIntervalSinceNow]*1000);
        if (!(self.aspectRatio > 0)) {
            [self setAspectRatioForImage:self.previewImage];
        }
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
        [self loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"loadImage for preview done");
            if (theImage) {
                [self setPreviewImageFromImage:theImage];
                if (finished != nil) {
                    finished(nil);
                }
            } else {
                NSLog(@"ERROR: Failed to get image %@", error);
                if (finished != nil) {
                    finished(error);
                }
            }
        }];
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
    
    for (AVMetadataItem *i in artworks)
    {
        NSString *keySpace = i.keySpace;
        UIImage *im = nil;
        
        if ([keySpace isEqualToString:AVMetadataKeySpaceID3])
        {
            NSDictionary *d = [i.value copyWithZone:nil];
            im = [UIImage imageWithData:[d objectForKey:@"data"]];
        }
        else if ([keySpace isEqualToString:AVMetadataKeySpaceiTunes])
            im = [UIImage imageWithData:[i.value copyWithZone:nil]];
        
        if (im)
            [artworkImages addObject:im];
    }
    // NSLog(@"array description is %@", [artworkImages description]);
    return artworkImages;
}

- (void) loadAudioAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    // TODO - find a way how to retrieve artwork from an a file
    NSArray * myArtworkImages = [[self class]artworksForFileAtFileURL: self.localURL];
    if ([myArtworkImages count]) {
        UIImage * myfirstImage = myArtworkImages[0];
        block(myfirstImage, nil);
    } else {
        block([UIImage imageNamed:@"audio-default.png"], nil);
    }
}

- (void) loadVcardAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    Vcard * myVcard = [[Vcard alloc] initWithVcardURL:self.contentURL];
    if (myVcard != nil) {
        UIImage * myPreviewImage = [myVcard previewImageWithScale:0];
        if (myPreviewImage) {
            block(myPreviewImage, nil);
            return;
        }
    }
    block([UIImage imageNamed:@"vcard_error_preview.png"], nil);
}

- (void) loadGeoLocationAttachmentImage: (ImageLoaderBlock) block {

    [self loadAttachmentDict:^(NSDictionary * geoLocation, NSError * error) {
        if (geoLocation != nil) {
            NSData * imageData = [NSData dataWithBase64EncodedString: geoLocation[@"previewImage"]];
            block([UIImage imageWithData: imageData], nil);
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
        NSLog(@"ERROR: no image url");
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
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
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
                                             absoluteURI:[self uploadURL]
                                                 payloadData:myData
                                                 payloadStream:nil
                                                 headers:[self uploadHttpHeaders]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate transferStarted];
            } else {
                if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"Attachment:uploadData - no delegate for transferStarted");}
            }
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (void) uploadStream {
    if (CONNECTION_TRACE) {NSLog(@"Attachment:uploadStream uploadURL=%@, attachment=%@", self.uploadURL, self );}
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
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
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                                         absoluteURI:[self uploadURL]
                                                             payloadData:nil
                                                             payloadStream:myEncryptingStream
                                                             headers:[self uploadHttpHeadersWithCrypto]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate transferStarted];
            } else {
                NSLog(@"Attachment:withUploadStream - no delegate to signal transferStarted");
            }
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

+ (BOOL)scanRange:(NSString*)theRange rangeStart:(long long*)rangeStart rangeEnd:(long long*)rangeEnd contentLength:(long long*)contentLength
{
    NSScanner * theScanner = [NSScanner scannerWithString:theRange];
    [theScanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@" ="]];
    return ([theScanner scanString:@"bytes" intoString:NULL] &&
            //[theScanner scanCharactersFromSet: intoString:NULL] &&
            [theScanner scanLongLong:rangeStart] &&
            [theScanner scanString:@"-" intoString:NULL] &&
            [theScanner scanLongLong:rangeEnd] &&
            [theScanner scanString:@"/" intoString:NULL] &&
            [theScanner scanLongLong:contentLength]
            );
}

- (void) checkResumeUploadStream {
    if (CONNECTION_TRACE) {NSLog(@"checkResumeUploadStream uploadURL=%@, attachment=%@", self.uploadURL, self );}
    
    GCNetworkRequest *request = [GCNetworkRequest requestWithURLString:self.uploadURL HTTPMethod:@"PUT" parameters:nil];
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
                              NSLog(@"checkResumeUploadStream got response status = %d,(%@) headers=%@", response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], response.allHeaderFields );
                              NSLog(@"response content=%@", [NSString stringWithData:data usingEncoding:NSUTF8StringEncoding]);
                          }
                          if (response.statusCode != 404) {
                              NSDictionary * myHeaders = response.allHeaderFields;
                              
                              NSString * myRangeString = myHeaders[@"Range"];
                              
                              if (myRangeString != nil) {
                                  
                                  long long rangeStart;
                                  long long rangeEnd;
                                  long long contentLength;
                                  
                                  if ([Attachment scanRange:myRangeString
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
                                      NSLog(@"checkResumeUploadStream irregular Content-Length %@, response status = %d, headers=%@",ContentLength, response.statusCode, response.allHeaderFields);
                                  }
                              }
                              
                          } else {
                              NSLog(@"checkResumeUploadStream irregular response status = %d, headers=%@", response.statusCode, response.allHeaderFields);
                          }
                          [self.chatBackend uploadFailed:self];
                      }
                           errorHandler:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                               NSLog(@"checkResumeUploadStream error response status = %d, headers=%@, error=%@", response.statusCode, response.allHeaderFields, error);
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
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
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
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferFinished];
        } else {
            NSLog(@"Attachment:withUploadStream - no delegate to signal transferStarted");
        }
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
                                                         absoluteURI:[self uploadURL]
                                                         payloadData:nil
                                                       payloadStream:myEncryptingStream
                                                             headers:[self uploadHttpHeadersWithCryptoFromPos:fromPos]
                                        ];
            self.cipherTransferSize = fromPos;
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            [self registerBackgroundTask];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate transferStarted];
            } else {
                NSLog(@"Attachment:withUploadStream - no delegate to signal transferStarted");
            }
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
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
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoing = %@", self.message.isOutgoing);
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
    if (CONNECTION_TRACE) {NSLog(@"truncating file size %llu to size %u, lastFullBlockPos=%u", fileSize, self.resumePos, lastFullBlockPos);}
    [Attachment truncateFileAtPath:myPath toSize:resumePos];
             
    self.cipherTransferSize = [NSNumber numberWithLongLong:resumePos]; // set transfered size to resume position
    self.cipheredSize = [self calcCipheredSize];
    NSNumber * lastBytePos = [NSNumber numberWithLongLong:[self.cipheredSize longLongValue]-1];
    
    self.decryptionEngine = nil;
    NSDictionary * myHeaders = [self downloadHttpHeadersWithStart: [NSNumber numberWithLongLong:lastFullBlockPos] withEnd:lastBytePos];
    
    
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                                 absoluteURI:[self remoteURL]
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
    if (progressIndicatorDelegate) {
        [progressIndicatorDelegate transferStarted];
    } else {
        if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"Attachment:download - no delegate for transferStarted");}
    }
}

- (void) download {
#ifdef NO_DOWNLOAD_RESUME    
    self.didResume = NO; // just for TESTING
#endif
    if (CONNECTION_TRACE) {NSLog(@"Attachment download remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );}
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoing = %@", self.message.isOutgoing);
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
        NSURL *appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
        self.ownedURL = [self localUrlForDownloadinDirectory: appDocDir];
    } else {
        // until we use ranged requests, let us delete the file in case it is left over
#ifdef NO_DOWNLOAD_RESUME
        NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
#else
        [self resumeDownload];
        return;
#endif
    }
    
    NSData * messageKey = self.message.cryptoKey;
    NSError * myError = nil;
    self.decryptionEngine = [[CryptoEngine alloc]
                               initWithOperation:kCCDecrypt
                               algorithm:kCCAlgorithmAES128
                               options:kCCOptionPKCS7Padding
                               key:messageKey
                               IV:nil
                               error:&myError];
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                     absoluteURI:[self remoteURL]
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
    if (progressIndicatorDelegate) {
        [progressIndicatorDelegate transferStarted];
    } else {
        if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"Attachment:download - no delegate for transferStarted");}
    }
}

- (void) downloadOnTimer: (NSTimer*) theTimer {
    if (theTimer != _transferRetryTimer) {
        NSLog(@"WARNING: downloadOnTimer: called by strange timer");
    } else {
        _transferRetryTimer = nil;
    }
    [self download];
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
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
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

-(void) withUploadStream: (StreamSetterBlock) execution {
    if (self.localURL != nil) {
        // NSLog(@"Attachment withUploadStream self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
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

-(NSDictionary*) uploadHttpHeadersWithCrypto {
    
    self.cipheredSize = [NSNumber numberWithInteger:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].integerValue]];
    
    NSDictionary * headers = @{@"Content-Type"       : @"application/octet-stream",
                               @"Content-Length"     : [self.cipheredSize stringValue]};
    if (CONNECTION_TRACE) {NSLog(@"uploadHttpHeadersWithCrypto: headers=%@", headers);}
    return headers;
}

-(NSDictionary*) uploadHttpHeadersWithCryptoFromPos:(NSNumber*) start {
    
    self.cipheredSize = [NSNumber numberWithInteger:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].integerValue]];

    NSInteger end = [self.cipheredSize integerValue] - 1;
    NSNumber * size = [NSNumber numberWithInteger:end - [start integerValue] + 1];
    
    NSDictionary * headers = @{@"Content-Range": [NSString stringWithFormat:@"bytes %@-%d/%d",start, end, [self.cipheredSize integerValue]],
                               @"Content-Type"       : @"application/octet-stream",
                               @"Content-Length"     : [size stringValue]};
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
- (NSString *) localUrlForDownloadinDirectory: (NSURL *) theDirectory {
    NSString * myRemoteURL = [NSURL URLWithString: [self remoteURL]];
    NSString * myRemoteFileName = myRemoteURL.lastPathComponent;
    NSURL * myNewFile = [NSURL URLWithString:myRemoteFileName relativeToURL:theDirectory];
    NSString * myNewFilename = [[[myNewFile absoluteString] stringByAppendingString:@"." ] stringByAppendingString: [Attachment fileExtensionFromMimeType: self.mimeType]];
    return myNewFilename;
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

+ (NSString*) translateFileURLToDocumentDirectory:(NSString*)someFileURL {
    if (someFileURL == nil) {
        return nil;
    }
    NSURL *appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myFileName = [someFileURL lastPathComponent];
    NSURL * myLocalURL = [NSURL URLWithString:myFileName relativeToURL:appDocDir];
    return [myLocalURL absoluteString];
}


+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType {
    if (theMimeType == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(theMimeType), NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    CFRelease(uti);
    return CFBridgingRelease(extension);
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
    return CFBridgingRelease(mimetype);
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
                self.transferConnection = nil; // make sure we do not get any more data
                if (CONNECTION_TRACE) {NSLog(@"### did set transferConnection to nil to avoid receiving data");}
                // NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
                // [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
            }
            
            // TODO: check if this is necessary and leads to duplicate error reporting
            NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection didReceiveResponse http status code =%ld", self.transferHttpStatusCode];
            if (CONNECTION_TRACE) {NSLog(@"%@", myDescription);}
            self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 667 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            if ([self.message.isOutgoing isEqualToNumber: @YES]) {
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
    NSError * myError = nil;
    NSURL * myURL = [NSURL URLWithString: fileURL];
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

+ (NSData*)readDataFromFileAtURL:(NSURL*)url atOffset:(NSUInteger)start withSize:(NSUInteger) length {
    NSString * myPath = [url path];
    return [Attachment readDataFromFileAtPath:myPath atOffset:start withSize:length];
}

+ (NSData*)readDataFromFileAtFileURLString:(NSString*)fileUrl atOffset:(NSUInteger)start withSize:(NSUInteger) length {
    NSURL * myURL = [NSURL URLWithString: fileUrl];
    return [Attachment readDataFromFileAtURL:myURL atOffset:start withSize:length];
}


+ (NSData*)readDataFromFileAtPath:(NSString*)filePath atOffset:(NSUInteger)start withSize:(NSUInteger) length {
        
    int fd = open([filePath UTF8String], O_RDONLY);
    
    if (fd == -1) {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, open failed, error=%d", length, errno);
        return nil;
    }
    
    int pos = lseek(fd, start, SEEK_SET);
    if (pos != start) {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, seek to %d returned %d, error=%d", start, pos, errno);
        close(fd);
        return nil;
    }
    
    NSMutableData* theData = [[NSMutableData alloc] initWithLength:length];
    
    if (theData) {
        void* buffer = [theData mutableBytes];
        NSUInteger bufferSize = [theData length];
        NSUInteger actualBytes = read(fd, buffer, bufferSize);
        if (actualBytes < length) {
            NSLog(@"ERROR: Attachment readDataFromFileAtPath, wanted %d bytes, got only %d", length, actualBytes);
            theData = nil;
        }
    } else {
        NSLog(@"ERROR: Attachment readDataFromFileAtPath, could not allocate NSData with len=%d", length);        
    }
    close(fd);
    
    return theData;
}

+ (void)truncateFileAtPath:(NSString*)filePath toSize:(NSUInteger) length {
    if (truncate([filePath UTF8String], length) != 0) {
        NSLog(@"Attachment: truncateFileAtPath: %@ toSize: %d failed, errno=%d", filePath, length, errno);
    }
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.chatBackend connection:connection willSendRequestForAuthenticationChallenge:challenge];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _transferConnection) {
        if (TRANSFER_TRACE) {NSLog(@"Attachment transferConnection didReceiveData len=%u", [data length]);}
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            NSError *myError = nil;
            if (self.resumePos != 0) {
                NSUInteger myFileSize = [[Attachment fileSize:self.ownedURL withError:&myError] unsignedLongValue];
                if (self.resumePos != myFileSize || self.decryptionEngine != nil) {
                    NSLog(@"ERROR: didReceiveData: can not resume; resumePos/fileSze mismatch or self.decryptionEngine!=nil; resumePos=%d fileSize=%d, decryptionEngine=%@, error=%@", self.resumePos, myFileSize, self.decryptionEngine, myError);
                    return;
                } else {
                    // resume
                    if (data.length < 16) {
                        NSLog(@"ERROR: didReceiveData: can not resume, first data chunk < 16 bytes, chunk size = %d", data.length);
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
                    if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection didReceiveData: resume crypto setup done, restlen=%u", [data length]);}
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
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate showTransferProgress: [self.transferSize floatValue] / [self.contentSize floatValue]];
            } else {
                if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"Attachment:didReceiveData - no delegate for showTransferProgress");}
            }
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
        if (TRANSFER_TRACE) {NSLog(@"Attachment transferConnection didSendBodyData %d", bytesWritten);}
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
        if (progressIndicatorDelegate) {
            // [progressIndicatorDelegate showTransferProgress: (float)totalBytesWritten / (float) totalBytesExpectedToWrite];
            [progressIndicatorDelegate showTransferProgress: [self.cipherTransferSize floatValue] / [self.cipheredSize floatValue]];
        } else {
            if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"didSendBodyData - no delegate for showTransferProgress");}
        }
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
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferFinished];
        } else {
            if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"didFailWithError - no delegate for transferFinished");}
        }
        if ([self.message.isOutgoing isEqualToNumber: @YES]) {
            [self.chatBackend uploadFailed:self];
        } else {
            [self.chatBackend downloadFailed:self];
        }
        [self unregisterBackgroundTask];
    } else {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _transferConnection) {
        if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection connectionDidFinishLoading %@", connection);}
        self.transferConnection = nil;

        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
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
                self.localURL = self.ownedURL;
                [self.chatBackend downloadFinished:self];
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
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferFinished];
        } else {
            if (CONNECTION_DELEGATE_DEBUG) {NSLog(@"connectionDidFinishLoading - no delegate for transferFinished");}
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection connectionDidFinishLoading without valid connection");
    }
}

- (void) registerBackgroundTask {
    UIApplication *app = [UIApplication sharedApplication];
    _backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler: ^{
        if (self.transferRetryTimer != nil) {
            [self.transferRetryTimer invalidate];
            self.transferRetryTimer = nil;
        }
        if (self.transferConnection != nil) {
            [self.transferConnection cancel];
            self.transferConnection = nil;
            [(AppDelegate*)app.delegate saveDatabase];
        }
        [app endBackgroundTask:_backgroundTaskId];
        _backgroundTaskId = UIBackgroundTaskInvalid;
    }];
}

- (void) unregisterBackgroundTask {
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
             @"fileName": @"humanReadableFileName"
             };
}

- (NSString*) attachmentJsonString {
    NSDictionary * myRepresentation = [HXOModel createDictionaryFromObject:self withKeys:self.JsonKeys];
    NSData * myJsonData = [NSJSONSerialization dataWithJSONObject: myRepresentation options: 0 error: nil];
    NSString * myJsonUTF8String = [[NSString alloc] initWithData:myJsonData encoding:NSUTF8StringEncoding];
    return myJsonUTF8String;
}

static const NSInteger kJsonRpcAttachmentParseError  = -32700;

-  (void) setAttachmentJsonString:(NSString*) theJsonString {
    NSError * error;
    id json = [NSJSONSerialization JSONObjectWithData: [theJsonString dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
    if (json == nil) {
        NSLog(@"ERROR: setAttachmentJsonString: JSON parse error: %@ on string %@", error.userInfo[@"NSDebugDescription"], theJsonString);
        return;
    }
    if ([json isKindOfClass: [NSDictionary class]]) {
        [HXOModel updateObject:self withDictionary:json withKeys:[self JsonKeys]];        
    } else {
        NSLog(@"ERROR: attachment json not encoded as dictionary, json string = %@", theJsonString);
    }
}
    
- (NSString*) attachmentJsonStringCipherText {
    return [self.message encryptString: self.attachmentJsonString];
}

-(void) setAttachmentJsonStringCipherText:(NSString*) theB64String {
    self.attachmentJsonString = [self.message decryptString:theB64String];
}

- (void) prepareForDeletion {
    [super prepareForDeletion];
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
    if (self.ownedURL.length > 0) {
        AppDelegate * delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
        NSError *error;
        NSDictionary * vars = @{ @"ownedURL" : self.ownedURL};
        NSFetchRequest *fetchRequest = [delegate.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByOwnedURL" substitutionVariables: vars];
        NSArray *messages = [delegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (messages == nil) {
            NSLog(@"Fetch request failed: %@", error);
            abort();
        }
        if (messages.count > 0) {
            if (messages.count == 1) {
                // delete ownedURL because it is only referenced by one message
                NSLog(@"Deleting ownedURL %@, not referenced by other messages", self.ownedURL);
                NSURL * myURL = [NSURL URLWithString:self.ownedURL];
                if ([myURL isFileURL]) {
                    [[NSFileManager defaultManager] removeItemAtURL:myURL error:nil];
                }
            } else {
                NSLog(@"Keeping ownedURL %@, is referenced by other messages", self.ownedURL);
            }
        }        
    }
    // remove from transfer queues
    [self.chatBackend dequeueDownloadOfAttachment:self];
    [self.chatBackend dequeueUploadOfAttachment:self];
}

@end
