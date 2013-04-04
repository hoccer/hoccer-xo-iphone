//
//  Attachment.m
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "Message.h"
#import <Foundation/NSURL.h>

@implementation Attachment

@dynamic localURL;
@dynamic mimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic contentSize;
@dynamic aspectRatio;

@dynamic message;
@synthesize image;

- (void) makeImageAttachment:(NSString *)theURL image:(UIImage*)theImage anOtherURL:(NSString *)theOtherURL {
    self.mediaType = @"image";
    self.mimeType = @"image/jpeg";
    NSURL * url = [NSURL URLWithString: theURL];
    if ([url.scheme isEqualToString: @"file"]) {
        self.localURL = theURL;
    } else if ([url.scheme isEqualToString: @"assets-library"]) {
        self.assetURL = theURL;
    } else {
        NSLog(@"unhandled URL scheme %@", url.scheme);        
    }
    if (theOtherURL != nil) {
        NSURL* anOtherUrl = [NSURL URLWithString: theOtherURL];
        if ([anOtherUrl.scheme isEqualToString: @"file"]) {
            self.localURL = theURL;
        } else if ([anOtherUrl.scheme isEqualToString: @"assets-library"]) {
            self.assetURL = theURL;
        } else {
            NSLog(@"unhandled URL otherURL scheme %@", anOtherUrl.scheme);
        }
    }
    if (theImage != nil) {
        self.image = theImage;
        self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
    } else {
        [self loadImage:^(UIImage* theImage, NSError* error) {
            if (theImage) {
                self.image = theImage;
                self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
            } else {
                NSLog(@"Failed to get image: %@", error);
            }
        }];
    }
}


- (UIImage *) symbolImage {
    return nil;
}

- (void) loadImage: (ImageLoaderBlock) block {
    if (self.localURL != nil) {
        block([UIImage imageWithContentsOfFile: [[NSURL URLWithString: self.localURL] path]], nil);
    } else if (self.assetURL != nil) {
        //TODO: handle different resolutions. For now just load a representation that is suitable for a chat bubble
        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {
            ALAssetRepresentation *rep = [myasset defaultRepresentation];
            //CGImageRef iref = [rep fullResolutionImage];
            CGImageRef iref = [rep fullScreenImage];
            if (iref) {
                block([UIImage imageWithCGImage:iref], nil);
            }
        };
        
        //
        ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
        {
            NSLog(@"Failed to get image %@ from asset library: %@", self.localURL, [myerror localizedDescription]);
            block(nil, myerror);
        };
        
        if(self.localURL && [self.localURL length] /*&& ![[self.localURL pathExtension] isEqualToString:AUDIO_EXTENSION]*/)
        {
            ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
            [assetslibrary assetForURL: [NSURL URLWithString: self.assetURL]
                           resultBlock: resultblock
                          failureBlock: failureblock];
        }
    } else {
        NSLog(@"no image url");
        block(nil, nil);
    }
}

@end
