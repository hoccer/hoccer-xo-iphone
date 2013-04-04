//
//  Attachment.h
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Message;

@interface Attachment : NSManagedObject

@property (nonatomic, strong) NSString * assetURL; // a url that typically starts with "assets-library://"
@property (nonatomic)         int64_t    contentSize; // file size in bytes
@property (nonatomic, strong) NSString * humanReadableFileName; // an optional human readable filename with any path component, mostly used for audio files
@property (nonatomic, strong) NSString * localURL; // a file url
@property (nonatomic, strong) NSString * ownedURL; // a file url to a file that is owned this attachment and will be removed when the Attachment is removed
@property (nonatomic, strong) NSString * mediaType; // image, audio, video, contact, other
@property (nonatomic, strong) NSString * mimeType; // mime type of the attachment

@property (nonatomic, strong) Message *message;

@property (nonatomic, readonly) UIImage *symbolImage;

@end
