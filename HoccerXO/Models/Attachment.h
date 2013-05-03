//
//  Attachment.h
//  HoccerXO
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "HXOModel.h"

@class HXOMessage;
@class HXOBackend;
@class CryptoEngine;

typedef void(^ImageLoaderBlock)(UIImage* theImage,NSError* theError);
typedef void(^SizeSetterBlock)(int64_t theSize,NSError* theError);
typedef void(^DataSetterBlock)(NSData* theData,NSError* theError);
typedef void(^StreamSetterBlock)(NSInputStream* theStream,NSError* theError);
typedef void(^CompletionBlock)(NSError* theError);

@protocol TransferProgressIndication <NSObject>

- (void) showTransferProgress:(float) theProgress;
- (void) transferStarted;
- (void) transferFinished;

@end


@interface Attachment : HXOModel < NSURLConnectionDelegate >

// persistent properties from model

@property (nonatomic, strong) NSString * assetURL;              // a url that typically starts with "assets-library://"
@property (nonatomic)         NSNumber * contentSize;           // authoritative file size in bytes; supports assignment by string
@property (nonatomic)         double     aspectRatio;           // ratio image width/height
@property (nonatomic, strong) NSString * humanReadableFileName; // an optional human readable filename with any path component, mostly used for audio files
@property (nonatomic, strong) NSString * localURL;              // a file url
@property (nonatomic, strong) NSString * ownedURL;              // a file url to a file that is owned this attachment and will be removed when the Attachment is removed
@property (nonatomic, strong) NSString * mediaType;             // image, audio, video, contact, other
@property (nonatomic, strong) NSString * mimeType;              // mime type of the attachment

@property (nonatomic, strong) NSString * remoteURL;             // remote URL where the file should/was uploaded
@property (nonatomic)         NSNumber * transferSize;          // number of plaintext bytes uploaded or downloaded; supports assignment by string
@property (nonatomic)         NSNumber * cipherTransferSize;    // number of ciphertext bytes uploaded or downloaded; supports assignment by string
@property (nonatomic)         NSNumber * cipheredSize;          // number of ciphertext bytes
@property (nonatomic)         NSInteger  transferFailures;       // number of upload or download failures
@property (nonatomic, strong) NSData   * previewImageData;           // remote URL where the file should/was uploaded
@property (nonatomic, strong) HXOMessage *message;

// virtual properties
@property (nonatomic) NSString * attachmentJsonString;
@property (nonatomic) NSString * attachmentJsonStringCipherText;

// These are non-persistent properties:

//@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) NSURLConnection *transferConnection;
@property (nonatomic, copy) NSError * transferError;
@property (nonatomic)       long transferHttpStatusCode;
@property (nonatomic, strong) NSTimer *transferRetryTimer;

@property (readonly, strong) NSDictionary * uploadHttpHeaders;
@property (readonly, strong) NSDictionary * uploadHttpHeadersWithCrypto;
@property (readonly, strong) NSDictionary * downloadHttpHeaders;

@property (readonly, strong, nonatomic) HXOBackend *  chatBackend;

@property (nonatomic, strong) id<TransferProgressIndication> progressIndicatorDelegate;

@property (nonatomic, strong) CryptoEngine * decryptionEngine;
@property (nonatomic, strong) CryptoEngine * encryptionEngine;

@property (nonatomic, strong) UIImage * previewImage;


// encryption/decryption properties


-(void) withUploadData: (DataSetterBlock) execution;

- (id < NSURLConnectionDelegate >) uploadDelegate;
- (id < NSURLConnectionDelegate >) downloadDelegate;

- (void) loadImage: (ImageLoaderBlock) block;

- (void) upload;
- (void) uploadData;
- (void) uploadStream;
- (void) download;
- (void) downloadOnTimer: (NSTimer*) theTimer;
- (void) uploadOnTimer: (NSTimer*) theTimer;

- (void) makeImageAttachment:(NSString *)theURL anOtherURL:(NSString *)otherURL image:(UIImage*)theImage withCompletion:(CompletionBlock)completion;
- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;
- (void) makeAudioAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;
- (void) makeVcardAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;

- (void) loadImageAttachmentImage: (ImageLoaderBlock) block;
- (void) loadPreviewImageIntoCacheWithCompletion:(CompletionBlock) block;

- (NSURL *) contentURL; // best Effort content URL for playback, display etc. (localURL if available, otherwise assetURL)
- (NSURL *) otherContentURL; // returns assetURL if localURL is available, otherwise nil

- (NSString *) localUrlForDownloadinDirectory: (NSURL *) theDirectory;

+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType;
+ (NSString *) mimeTypeFromfileExtension: (NSString *) theExtension;
+ (NSString *) mimeTypeFromURLExtension: (NSString *) theURLString;
+ (UIImage *) qualityAdjustedImage:(UIImage *)theFullImage;
+ (BOOL) tooLargeImage:(UIImage *)theFullImage;

@end
