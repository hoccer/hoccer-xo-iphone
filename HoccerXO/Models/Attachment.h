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
@class Attachment;
@class Contact;
@class Preview;

typedef void(^ImageLoaderBlock)(UIImage* theImage,NSError* theError);
typedef void(^SizeSetterBlock)(int64_t theSize,NSError* theError);
typedef void(^DataSetterBlock)(NSData* theData,NSError* theError);
typedef void(^StreamSetterBlock)(NSInputStream* theStream,NSError* theError);
typedef void(^CompletionBlock)(NSError* theError);
typedef void(^DictLoaderBlock)(NSDictionary* theDict,NSError* theError);
typedef void(^MACSetterBlock)(NSData* theMAC,NSError* theError);
typedef void(^OkBlock)();
typedef void (^AttachmentCompletionBlock)(Attachment *, NSError*);
typedef void (^StringCompletionBlock)(NSString * string);

typedef void(^UploadProgessBlock)(NSUInteger bytesWritten, NSUInteger totalBytesWritten, NSUInteger totalBytesExpectedToWrite);
typedef void(^DownloadProgessBlock)(NSUInteger bytesRead, NSUInteger totalBytesRead, NSUInteger totalBytesExpectedToRead);

typedef enum AttachmentStates {
    kAttachmentDetached,
    kAttachmentEmpty,
    kAttachmentTransfered,
    kAttachmentNoTransferURL,
    kAttachmentTransfersExhausted,
    kAttachmentTransfering,
    kAttachmentTransferScheduled,
    kAttachmentUploadIncomplete,
    kAttachmentDownloadIncomplete,
    kAttachmentTransferOnHold,
    kAttachmentWantsTransfer,
    kAttachmentTransferPaused,
    kAttachmentTransferAborted
} AttachmentState;

@protocol AttachmentUIDelegate <NSObject>

- (void) attachment: (Attachment*) attachment transferDidProgress:(float) theProgress;
- (void) attachmentTransferStarted: (Attachment*) attachment;
- (void) attachmentTransferFinished: (Attachment*) attachment;
- (void) attachmentTransferScheduled: (Attachment*) attachment;

- (void) attachmentDidChangeAspectRatio: (Attachment*) attachment;
@end


@interface Attachment : HXOModel < NSURLConnectionDelegate,UIActivityItemSource >

// persistent properties from model

@property (nonatomic, strong) NSString * assetURL;              // a url that typically starts with "assets-library://"
@property (nonatomic)         NSNumber * contentSize;           // authoritative file size in bytes; supports assignment by string
@property (nonatomic)         double     aspectRatio;           // ratio image width/height
@property (nonatomic, strong) NSString * humanReadableFileName; // an optional human readable filename without any path component, mostly used for audio files
@property (nonatomic, strong) NSString * localURL;              // a file url
@property (nonatomic, strong) NSString * ownedURL;              // a file url to a file that is owned this attachment and will be removed when the Attachment is removed
@property (nonatomic, strong) NSString * mediaType;             // image, audio, video, contact, other
@property (nonatomic, strong) NSString * mimeType;              // mime type of the attachment

@property (nonatomic, strong) NSString * remoteURL;             // remote URL where the file can be downloaded
@property (nonatomic, strong) NSString * uploadURL;             // remote URL where the file should be uploaded
@property (nonatomic)         NSNumber * transferSize;          // number of plaintext bytes uploaded or downloaded; supports assignment by string
@property (nonatomic)         NSNumber * cipherTransferSize;    // number of ciphertext bytes uploaded or downloaded; supports assignment by string
@property (nonatomic)         NSNumber * cipheredSize;          // number of ciphertext bytes
@property (nonatomic)         int        transferFailures;      // number of upload or download failures (is 32 Bit field in database)
@property (nonatomic)         NSString * playable;              // whether the attachment can be played on the device (can be "YES", "NO", "UNKNOWN")
@property (nonatomic, strong) NSData   * previewImageData;      // remote URL where the file should/was uploaded
@property (nonatomic, strong) NSDate   * transferPaused;        // if not nil it containes the date the transfer was paused by the user
@property (nonatomic, strong) NSDate   * transferAborted;       // if not nil it containes the date the transfer was aborted by the user
@property (nonatomic, strong) NSDate   * transferFailed;        // if not nil it containes the date the transfer has failed the last time
@property (nonatomic, strong) HXOMessage *message;
@property (nonatomic, strong) NSSet * collectionItems;
@property (nonatomic, strong) NSData * sourceMAC;               // Message Authentication Code computed at data source
@property (nonatomic, strong) NSData * destinationMAC;          // Message Authentication Code computed at data destination
@property (nonatomic, strong) NSString * origCryptedJsonString; // the original encrypted json rep. of the incoming attachment for hmac calculation
// new properties with Model Version 46 not reliably available yet on old databse
@property (nonatomic)         double     width;                  // width for images and movies
@property (nonatomic)         double     height;                 // width for images and movies
@property (nonatomic, strong) NSString * entityTag;              // some content (file) unique tag that changes when the content changes
@property (nonatomic, strong) NSString * duplicate;              // set to "YES" when there is at another attachment with the same content url that has the duplicate value not set
@property (nonatomic, strong) NSString * universalType;          // the UTI
@property (nonatomic, strong) NSDate   * creationDate;           // date when this record was created
// new properties with Model Version 47 not reliably available yet on old databse
@property (nonatomic, strong) NSString * fileStatus;             // indicates the status of the referenced file, currently only "DOES_NOT_EXIST"
//@property (nonatomic)         NSNumber * orderNumber;          // number of ciphertext bytes
@property (nonatomic, strong) NSDate   * fileModificationDate;   // lastModifiedDate of attached file
@property (nonatomic, strong) Contact  * savedByContact;         // contact who selected this attachment when the view was removed

@property (nonatomic, strong) Preview  * previewStore;         // contact who selected this attachment when the view was removed
// virtual properties
@property (nonatomic) NSString * attachmentJsonString;
@property (nonatomic) NSString * attachmentJsonStringCipherText;

// These are non-persistent properties:
@property (nonatomic, strong) NSURLConnection *transferConnection;
@property (nonatomic, copy) NSError * transferError;
@property (nonatomic)       long transferHttpStatusCode;
@property (nonatomic, strong) NSTimer *transferRetryTimer;

@property (readonly, strong) NSDictionary * uploadHttpHeaders;
@property (readonly, strong) NSDictionary * uploadHttpHeadersWithCrypto;
@property (readonly, strong) NSDictionary * downloadHttpHeaders;

@property (readonly, strong, nonatomic) HXOBackend *  chatBackend;

@property (nonatomic, weak) id<AttachmentUIDelegate> uiDelegate;

@property (nonatomic, strong) CryptoEngine * decryptionEngine;
@property (nonatomic, strong) CryptoEngine * encryptionEngine;

@property (nonatomic, strong) UIImage * previewImage;
@property (nonatomic, strong) UIImage * previewIcon;

@property (readonly) AttachmentState state;

@property (nonatomic) NSString * sourceMACString;

@property (nonatomic) NSUInteger resumePos;

// These properties only consider attachment state
// See properties in Delivery to also consider attachment delivery state
@property (readonly) BOOL available; // return true if attachment is outgoing or transfered
@property (readonly) BOOL outgoing;  // return true if attachment is outgoing
@property (readonly) BOOL incoming;  // return true if attachment is incoming
@property (readonly) BOOL uploadable; // return true if attachment is outgoing, complete and not yet transfered
@property (readonly) BOOL downloadable; // return true if attachment is outgoing, complete and not yet transfered

-(void) computeSourceMac;
-(void) computeDestMac;

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
    
- (void) pauseTransfer;
- (void) unpauseTransfer;

- (void) makeImageAttachment:(NSString *)theURL anOtherURL:(NSString *)otherURL image:(UIImage*)theImage withCompletion:(CompletionBlock)completion;
- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;
- (void) makeAudioAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;
- (void) makeVcardAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion;
- (void) makeGeoLocationAttachment: (NSString*) theURL anOtherURL: (NSString*) theOtherURL withCompletion: (CompletionBlock) completion;
- (void) makeDataAttachment: (NSString*) theURL anOtherURL: (NSString*) theOtherURL withCompletion: (CompletionBlock) completion;

+ (Attachment*) makeAttachmentWithMediaType:(NSString*)mediaType
                                   mimeType:(NSString*)mimeType
                      humanReadableFileName:(NSString*)humanReadableFileName
                                   localURL:(NSString*)localURL
                                   assetURL:(NSString*)assetURL
                                  inContext:(NSManagedObjectContext*)context
                                  whenReady:(AttachmentCompletionBlock)attachmentCompleted;

- (void) reinitializeInContext:(NSManagedObjectContext*)context
                     whenReady:(AttachmentCompletionBlock)attachmentCompleted;

- (void) loadImageAttachmentImage: (ImageLoaderBlock) block;
- (void) loadPreviewImageIntoCacheWithCompletion:(CompletionBlock) block;
- (void) ensurePreviewImageWithCompletion:(CompletionBlock)finished;

- (void) loadAttachmentDict: (DictLoaderBlock) block;

- (NSURL *) contentURL; // best Effort content URL for playback, display etc. (localURL if available, otherwise assetURL)
- (NSURL *) otherContentURL; // returns assetURL if localURL is available, otherwise nil

- (NSNumber*) calcCipheredSize;

- (BOOL) overTransferLimit:(BOOL)isOutgoing;
- (void) trySaveToAlbum;
- (void) determinePlayability;

- (BOOL)fileUnavailable;
//- (void)protectFile;
//- (void)unprotectFile;

- (void)performSafeDeletion;

+(BOOL)deleteFileAtUrl:(NSURL*)myURL;

- (Attachment *) clone;
- (Attachment*) cloneWithCompletion:(AttachmentCompletionBlock)attachmentCompleted;

+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType;
+ (NSString *) mimeTypeFromfileExtension: (NSString *) theExtension;
+ (NSString *) mimeTypeFromURLExtension: (NSString *) theURLString;
+ (NSString *) mimeTypeFromUTI: (NSString *) uti;
+ (NSString *) UTIfromMimeType:(NSString*)mimeType;
+ (NSString *) UTIFromfileExtension: (NSString *) theExtension;
+ (NSString*) localizedDescriptionOfUTI:(NSString*)uti;
+ (NSString*) localizedDescriptionOfMimeType:(NSString*)mimeType;

+ (UIImage *) qualityAdjustedImage:(UIImage *)theFullImage;
+ (BOOL) tooLargeImage:(UIImage *)theFullImage;
+ (NSString*) getStateName:(AttachmentState)state;

+ (NSArray*)allMediaTypes;
+ (NSArray*)audioVideoMediaTypes;
+ (NSArray*)visualMediaTypes;
+ (NSArray*)audioMediaTypes;
+ (NSArray*)imageMediaTypes;
+ (NSArray*)otherMediaTypes;

@end
