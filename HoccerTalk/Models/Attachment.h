//
//  Attachment.h
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "HoccerTalkModel.h"

@class TalkMessage;
@class HoccerTalkBackend;

typedef void(^ImageLoaderBlock)(UIImage* theImage,NSError* theError);
typedef void(^SizeSetterBlock)(int64_t theSize,NSError* theError);
typedef void(^DataSetterBlock)(NSData* theData,NSError* theError);

@interface Attachment : HoccerTalkModel < NSURLConnectionDelegate >

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
@property (nonatomic)         NSNumber * transferSize;          // number of bytes uploaded; supports assignment by string

@property (nonatomic, strong) TalkMessage *message;

// These are non-persistent properties

@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) NSURLConnection *transferConnection;

@property (readonly, strong) NSDictionary * uploadHttpHeaders;
@property (readonly, strong) NSDictionary * downloadHttpHeaders;

@property (readonly, strong, nonatomic) HoccerTalkBackend *  chatBackend;

-(void) withUploadData: (DataSetterBlock) execution;

- (id < NSURLConnectionDelegate >) uploadDelegate;
- (id < NSURLConnectionDelegate >) downloadDelegate;

- (void) loadImage: (ImageLoaderBlock) block;

- (void) upload;
- (void) download;
- (void) downloadLater: (NSTimer*) theTimer;

- (void) makeImageAttachment:(NSString *)theURL image:(UIImage*)theImage;
- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL;
- (void) makeAudioAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL;

- (NSURL *) contentURL; // best Effort content URL for playback, display etc.

- (NSString *) localUrlForDownloadinDirectory: (NSURL *) theDirectory;

+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType;
+ (NSString *) mimeTypeFromfileExtension: (NSString *) theExtension;
+ (NSString *) mimeTypeFromURLExtension: (NSString *) theURLString;

@end
