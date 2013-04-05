//
//  Attachment.m
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "TalkMessage.h"
#import <Foundation/NSURL.h>
#import <MediaPlayer/MPMoviePlayerController.h>

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


- (void) useURLs:(NSString *)theURL anOtherURL:(NSString *)theOtherURL {
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
    NSError *myError = nil;
    if (self.localURL != nil) {
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        self.contentSize = [[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:&myError] fileSize];
        if (myError != nil) {
            NSLog(@"can not determine size of file '%@'", myPath);
        }
        NSLog(@"Size = %lld (of file '%@')", self.contentSize, myPath);
    }
    if (self.assetURL != nil) {
        [self assetSizer:^(int64_t theSize, NSError * theError) {
            self.contentSize = theSize;
            NSLog(@"Asset Size = %lld (of file '%@')", self.contentSize, self.assetURL);
        } url:self.assetURL];
    }
}

- (void) loadImage: (ImageLoaderBlock) block {
    if ([self.mediaType isEqualToString: @"image"]) {
        [self loadImageAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"video"]) {
        [self loadVideoAttachmentImage: block];
    }
}

- (void) loadImageIntoCache {
    [self loadImage:^(UIImage* theImage, NSError* error) {
        if (theImage) {
            self.image = theImage;
            self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
        } else {
            NSLog(@"Failed to get image: %@", error);
        }
    }];
}

- (void) makeImageAttachment:(NSString *)theURL image:(UIImage*)theImage {
    self.mediaType = @"image";
    self.mimeType = @"image/jpeg";
    
    [self useURLs: theURL anOtherURL:nil];
    
    if (theImage != nil) {
        self.image = theImage;
        self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
    } else {
        [self loadImageIntoCache];
    }
}

- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL {
    self.mediaType = @"video";
    self.mimeType = @"video/mpeg";
    
    [self useURLs: theURL anOtherURL: theOtherURL];    
    [self loadImageIntoCache];  
}

- (void) assetSizer: (SizeSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        int64_t mySize = [rep size];
        block(mySize, nil);
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];

}

- (void) loadVideoAttachmentImage: (ImageLoaderBlock) block {

    // synchronous loading, maybe make it async at some point
    MPMoviePlayerController * movie = [[MPMoviePlayerController alloc]
                                       initWithContentURL:[NSURL URLWithString:self.localURL]];
    UIImage * myImage = [movie thumbnailImageAtTime:0.0 timeOption:MPMovieTimeOptionExact];
    block(myImage, nil);
}


- (void) loadImageAttachmentImage: (ImageLoaderBlock) block {
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
