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

@property (nonatomic,readonly) NSString * audioTitle;
@property (nonatomic,readonly) NSString * audioArtist;
@property (nonatomic,readonly) NSString * audioAlbum;
@property (nonatomic,readonly) NSTimeInterval audioDuration;
@property (nonatomic,readonly) NSString * audioArtistAndAlbum;
@property (nonatomic,readonly) NSString * audioArtistAlbumAndDuration;

@property (nonatomic,readonly) BOOL attachmentInfoLoaded;

@end
