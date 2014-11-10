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

#import "AppDelegate.h"
#import "CoreLocation/CoreLocation.h"

#import "ImageIO/ImageIO.h"

@implementation AttachmentInfo

+ (AttachmentInfo *) infoForAttachment:(Attachment *)attachment {
    AttachmentInfo *info;

    NSCache *cache = [AttachmentInfo cache];
    NSString *key = attachment.localURL;

    if (key) {
        info = [cache objectForKey:key];
    }
    
    if (!info) {
        info = [[AttachmentInfo alloc] initWithAttachment:attachment];
        
        if (key) {
            [cache setObject:info forKey:key];
        }
    }
    
    return info;
}

+ (NSCache *) cache {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
    });
    
    return cache;
}

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
    [self loadInfoForGenericAttachment:attachment];
    if ([attachment.mediaType isEqualToString: @"vcard"]) {
        [self loadInfoForVCardAttachment:attachment];
    } else if ([attachment.mediaType isEqualToString: @"audio"] || [attachment.mediaType isEqualToString: @"video"]) {
        [self loadInfoForAudioAttachment:attachment];
    } else if ([attachment.mediaType isEqualToString: @"image"]) {
        [self loadInfoForImageAttachment:attachment];
    } else if ([attachment.mediaType isEqualToString: @"geolocation"]) {
        [self loadInfoForGeolocationAttachment:attachment];
    }

    _attachmentInfoLoaded = YES;
}

+ (NSString *)labelForDate:(NSDate*)date {
    
    NSDateFormatter *df             = [[NSDateFormatter alloc] init];
    df.locale                       = [NSLocale currentLocale];
    df.dateStyle                    = NSDateFormatterMediumStyle;
    df.timeStyle                    = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting   = YES;
    
    return [df stringFromDate:date];
}

+ (NSString *)labelForDuration:(NSTimeInterval)duration {
    return [NSString stringWithFormat:@"%02lu:%02lu", ((unsigned long)duration)/60, ((unsigned long)duration)%60];
}

- (void) loadInfoForGeolocationAttachment: (Attachment *) attachment {
    [attachment loadAttachmentDict:^(NSDictionary *geoLocation, NSError *theError) {
        if (geoLocation) {
            NSArray * coordinates = geoLocation[@"location"][@"coordinates"];
            //NSLog(@"geoLocation=%@",geoLocation);
            // NSLog(@"coordinates=%@",coordinates);
            //CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([coordinates[0] doubleValue], [coordinates[1] doubleValue]);
            _location = [NSString stringWithFormat:@"%f,%f",[coordinates[0] doubleValue], [coordinates[1] doubleValue]];
        }
    }];
}

- (void) loadInfoForVCardAttachment: (Attachment *) attachment {
    Vcard * myVcard = [[Vcard alloc] initWithVcardURL:attachment.contentURL];
    if (myVcard != nil) {
        _vcardName = myVcard.nameString;
        _vcardOrganization = myVcard.organization;
        _vcardPreviewName = myVcard.previewName;
        
        NSArray * emails = myVcard.emails;
        if (emails && emails.count > 0) {
            VcardMultiValueItem * firstMail = emails[0];
            _vcardEmail = firstMail.value;
            if (_vcardPreviewName == nil) {
                _vcardPreviewName = _vcardEmail;
            }
        }
    }
}

- (void) loadInfoForAudioAttachment: (Attachment *) attachment {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:attachment.contentURL options:nil];

    CMTime audioDuration = asset.duration;
    _avDuration = CMTimeGetSeconds(audioDuration);
    _duration = [AttachmentInfo labelForDuration:_avDuration];

    NSArray * metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyTitle keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _audioTitle = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    if (self.audioTitle == nil || self.audioTitle.length == 0) {
        if ([attachment.humanReadableFileName hasPrefix:@"recording"]) {
            _audioTitle = NSLocalizedString(@"attachment_type_audio_recording", nil);
        } else {
            _audioTitle = attachment.humanReadableFileName;
        }
    }

    metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyArtist keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _audioArtist = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyAlbumName keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _audioAlbum = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyFormat keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _avFormat = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyDescription keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _avDescription = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    metaData = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata withKey:AVMetadataCommonKeyLocation keySpace:AVMetadataKeySpaceCommon];
    if (metaData.count > 0) {
        AVMetadataItem * metaItem = metaData[0];
        _location = [metaItem.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

}

- (void) loadInfoForImageAttachment: (Attachment *) attachment {
    
    if (attachment.height > 0) {
        _frameSize = [NSString stringWithFormat:@"%fx%f", attachment.width, attachment.height];
        return;
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[attachment contentURL], NULL);
    if (imageSource == NULL) {
        // Error loading image
        NSLog(@"loadInfoForImageAttachment: failed to load attachment image %@", attachment.contentURL);
        return;
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], (NSString *)kCGImageSourceShouldCache,
                             nil];
    
    CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
    if (imageProperties) {
        NSNumber *width = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
        NSNumber *height = (NSNumber *)CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
        
        NSLog(@"Image dimensions: %@ x %@ px", width, height);
        
        attachment.width = [width doubleValue];
        attachment.height = [height doubleValue];
        _frameSize = [NSString stringWithFormat:@"%@x%@", width, height];
        
        
        CFDictionaryRef exif = CFDictionaryGetValue(imageProperties, kCGImagePropertyExifDictionary);
        if (exif) {
            NSString *dateTakenString = (NSString *)CFDictionaryGetValue(exif, kCGImagePropertyExifDateTimeOriginal);
            if (dateTakenString != nil) {
                NSLog(@"Date Taken: %@", dateTakenString);
                _creationDate = dateTakenString;
            }
        }
        
        CFDictionaryRef tiff = CFDictionaryGetValue(imageProperties, kCGImagePropertyTIFFDictionary);
        if (tiff) {
            NSString *cameraModel = (NSString *)CFDictionaryGetValue(tiff, kCGImagePropertyTIFFModel);
            if (cameraModel) NSLog(@"Camera Model: %@", cameraModel);
        }
        
        CFDictionaryRef gps = CFDictionaryGetValue(imageProperties, kCGImagePropertyGPSDictionary);
        if (gps) {
            NSString *latitudeString = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLatitude);
            NSString *latitudeRef = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLatitudeRef);
            NSString *longitudeString = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLongitude);
            NSString *longitudeRef = (NSString *)CFDictionaryGetValue(gps, kCGImagePropertyGPSLongitudeRef);
            NSLog(@"GPS Coordinates: %@ %@ / %@ %@", longitudeString, longitudeRef, latitudeString, latitudeRef);
            _location = [NSString stringWithFormat:@"%@ %@ / %@ %@", longitudeString, longitudeRef, latitudeString, latitudeRef];
        }
        CFRelease(imageProperties);
    }
    CFRelease(imageSource);
    
}

- (void) loadInfoForGenericAttachment: (Attachment *) attachment {
    _dataSize = [AppDelegate memoryFormatter:[[attachment contentSize] longLongValue]];
    NSURL * contentURL = attachment.contentURL;
    if (contentURL.isFileURL) {
        NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:contentURL.path error:nil];
        if (attributes) {
            NSDate * creationDate = [attributes fileCreationDate];
            _creationDate = [AttachmentInfo labelForDate:creationDate];
        } else {
            NSLog(@"loadInfoForGenericAttachment: no attributes for url %@", contentURL);
        }
    }
    _typeDescription = [Attachment localizedDescriptionOfMimeType:attachment.mimeType];
    if (attachment.humanReadableFileName.length > 0) {
        _filename = attachment.humanReadableFileName;
    } else {
        _filename = [attachment.contentURL lastPathComponent];
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
    NSString * duration = [NSString stringFromTimeInterval:self.avDuration];
    if (artistAndAlbum) {
        return [NSString stringWithFormat:@"%@ – %@", artistAndAlbum, duration];
    } else {
        return duration;
    }
}

@end
