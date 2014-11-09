//
//  AttachmentInfo.h
//  HoccerXO
//
//  Created by Guido Lorenz on 29.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;

@interface AttachmentInfo : NSObject

+ (AttachmentInfo *) infoForAttachment:(Attachment *)attachment;

@property (nonatomic,readonly) NSString * vcardName;
@property (nonatomic,readonly) NSString * vcardOrganization;
@property (nonatomic,readonly) NSString * vcardEmail;
@property (nonatomic,readonly) NSString * vcardPreviewName;

@property (nonatomic,readonly) NSString * audioTitle;
@property (nonatomic,readonly) NSString * audioArtist;
@property (nonatomic,readonly) NSString * audioAlbum;
@property (nonatomic,readonly) NSTimeInterval avDuration;
@property (nonatomic,readonly) NSString * audioArtistAndAlbum;
@property (nonatomic,readonly) NSString * audioArtistAlbumAndDuration;

@property (nonatomic,readonly) NSString * avFormat;
@property (nonatomic,readonly) NSString * avDescription;

@property (nonatomic,readonly) NSString * frameSize; // audio, video and artwork size
@property (nonatomic,readonly) NSString * dataSize;
@property (nonatomic,readonly) NSString * duration;
@property (nonatomic,readonly) NSString * location;
@property (nonatomic,readonly) NSString * creationDate;

@property (nonatomic,readonly) NSString * filename;

@property (nonatomic,readonly) NSString * typeDescription;

@property (nonatomic,readonly) BOOL attachmentInfoLoaded;

@end
