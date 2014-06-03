//
//  AttachmentInfo.m
//  HoccerXO
//
//  Created by Guido Lorenz on 29.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AttachmentInfo.h"

#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVMetadataFormat.h>
#import <AVFoundation/AVMetadataItem.h>

#import "Attachment.h"
#import "NSString+FromTimeInterval.h"
#import "Vcard.h"

@implementation AttachmentInfo

- (id) initWithAttachment: (Attachment *) attachment {
    self = [super init];
    if (self && attachment.available) {
        [self loadInfoForAttachment: attachment];
        return self;
    } else {
        return nil;
    }
}

- (void) loadInfoForAttachment: (Attachment *) attachment {
    if ([attachment.mediaType isEqualToString: @"vcard"]) {
        [self loadInfoForVCardAttachment:attachment];
    } else if ([attachment.mediaType isEqualToString: @"audio"]) {
        [self loadInfoForAudioAttachment:attachment];
    }

    _attachmentInfoLoaded = YES;
}

- (void) loadInfoForVCardAttachment: (Attachment *) attachment {
    Vcard * myVcard = [[Vcard alloc] initWithVcardURL:attachment.contentURL];
    if (myVcard != nil) {
        _vcardName = myVcard.nameString;
        _vcardOrganization = myVcard.organization;
        NSArray * emails = myVcard.emails;
        if (emails && emails.count > 0) {
            VcardMultiValueItem * firstMail = emails[0];
            _vcardEmail = firstMail.value;
        }
    }
}

- (void) loadInfoForAudioAttachment: (Attachment *) attachment {
    NSRange findResult = [attachment.humanReadableFileName rangeOfString:@"recording"];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:attachment.contentURL options:nil];

    CMTime audioDuration = asset.duration;
    _audioDuration = CMTimeGetSeconds(audioDuration);
    if ( ! (findResult.length == @"recording".length && findResult.location == 0)) {
        NSArray * metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
        if (metaData.count > 0) {
            AVMetadataItem * metaItem = metaData[0];
            _audioTitle = metaItem.stringValue;
        }

        if (self.audioTitle == nil || self.audioTitle.length == 0) {
            _audioTitle = attachment.humanReadableFileName;
        }

        metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
        if (metaData.count > 0) {
            AVMetadataItem * metaItem = metaData[0];
            _audioArtist = metaItem.stringValue;
        }
        
        metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
        if (metaData.count > 0) {
            AVMetadataItem * metaItem = metaData[0];
            _audioAlbum = metaItem.stringValue;
        }
    }
}

- (NSString *) audioArtistAndAlbum {
    if (self.audioArtist && self.audioAlbum) {
        return [NSString stringWithFormat:@"%@ – %@", self.audioArtist, self.audioAlbum];
    } else if (self.audioArtist || self.audioAlbum) {
        return self.audioAlbum ? self.audioAlbum : self.audioArtist;
    } else {
        return nil;
    }
}

- (NSString *) audioArtistAlbumAndDuration {
    NSString * artistAndAlbum = self.audioArtistAndAlbum;
    NSString * duration = [NSString stringFromTimeInterval:self.audioDuration];
    if (artistAndAlbum) {
        return [NSString stringWithFormat:@"%@ – %@", artistAndAlbum, duration];
    } else {
        return duration;
    }
}

@end
