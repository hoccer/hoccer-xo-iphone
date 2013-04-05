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

typedef void(^ImageLoaderBlock)(UIImage*,NSError*);
typedef void(^SizeSetterBlock)(int64_t theSize,NSError*);

@interface Attachment : HoccerTalkModel

@property (nonatomic, strong) NSString * assetURL; // a url that typically starts with "assets-library://"
@property (nonatomic)         int64_t    contentSize; // file size in bytes
@property (nonatomic)         double     aspectRatio; // ratio image width/height
@property (nonatomic, strong) NSString * humanReadableFileName; // an optional human readable filename with any path component, mostly used for audio files
@property (nonatomic, strong) NSString * localURL; // a file url
@property (nonatomic, strong) NSString * ownedURL; // a file url to a file that is owned this attachment and will be removed when the Attachment is removed
@property (nonatomic, strong) NSString * mediaType; // image, audio, video, contact, other
@property (nonatomic, strong) NSString * mimeType; // mime type of the attachment

@property (nonatomic, strong) TalkMessage *message;

@property (nonatomic, strong) UIImage *image;

- (void) loadImage: (ImageLoaderBlock) block;
- (void) assetSizer: (SizeSetterBlock) block url:(NSString*)theAssetURL;

- (void) makeImageAttachment:(NSString *)theURL image:(UIImage*)theImage;
- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL;

- (void) useURLs:(NSString *)theURL anOtherURL:(NSString *)theOtherURL;

                 
@end
