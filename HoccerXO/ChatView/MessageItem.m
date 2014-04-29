//
//  MessageItem.m
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageItem.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVMetadataItem.h>
#import <AVFoundation/AVMetadataFormat.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>

#import "HXOMessage.h"
#import "Attachment.h"
#import "HXOHyperLabel.h"
#import "Vcard.h"


static NSDataDetector * _linkDetector;

@implementation MessageItem

@synthesize attributedBody = _attributedBody;

+ (void) initialize {
    NSTextCheckingTypes types = NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber;
    NSError * error = nil;
    _linkDetector = [NSDataDetector dataDetectorWithTypes: types error:&error];
    if (error != nil) {
        NSLog(@"failed to create regex: %@", error);
        _linkDetector = nil;
    }
}

- (id) initWithMessage: (HXOMessage*) message {
    self = [super init];
    if (self) {
        _attachmentInfoLoaded = NO;
        self.message = message;
    }
    return self;
}

- (void) setMessage:(HXOMessage *)message {
    _message = message;
    if (message.attachment && message.attachment.available && ! self.attachmentInfoLoaded) {
        [self loadAttachmentInfo];
    }
}

- (NSAttributedString*) attributedBody {
    if ( ! _attributedBody && self.message.body.length > 0) {
        _attributedBody = [self messageBodyWithLinks];
    }
    return _attributedBody;
}

- (NSAttributedString*) messageBodyWithLinks {
    NSMutableAttributedString * body = [[NSMutableAttributedString alloc] initWithString: self.message.body];
    [body addLinksMatching: _linkDetector];
    return body;
}

- (void) loadAttachmentInfo {
    if ([self.message.attachment.mediaType isEqualToString: @"vcard"]) {
        Vcard * myVcard = [[Vcard alloc] initWithVcardURL:self.message.attachment.contentURL];
        if (myVcard != nil) {
            _vcardName = myVcard.nameString;
            _vcardOrganization = myVcard.organization;
            NSArray * emails = myVcard.emails;
            if (emails && emails.count > 0) {
                VcardMultiValueItem * firstMail = emails[0];
                _vcardEmail = firstMail.value;
            }
        }

    } else if ([self.message.attachment.mediaType isEqualToString: @"audio"]) {
        NSRange findResult = [self.message.attachment.humanReadableFileName rangeOfString:@"recording"];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.message.attachment.contentURL options:nil];
        CMTime audioDuration = asset.duration;
        _audioDuration = CMTimeGetSeconds(audioDuration);
        if ( ! (findResult.length == @"recording".length && findResult.location == 0)) {
            NSArray * metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
            AVMetadataItem * metaItem;
            if (metaData.count > 0) {
                metaItem = metaData[0];
                _audioTitle = metaItem.stringValue;
            }
            metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
            if (metaData.count > 0) {
                metaItem = metaData[0];
                _audioArtist = metaItem.stringValue;
            }

            metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
            if (metaData.count > 0) {
                metaItem = metaData[0];
                _audioAlbum = metaItem.stringValue;
            }

        }
    }

    _attachmentInfoLoaded = YES;
}

@end
