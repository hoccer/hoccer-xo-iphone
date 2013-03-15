//
//  ImageAttachment.m
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageAttachment.h"

#import <AssetsLibrary/AssetsLibrary.h>

@implementation ImageAttachment

@dynamic width;
@dynamic height;

- (CGFloat) aspectRatio {
    return self.height.floatValue / self.width.floatValue;
}

- (void) loadImage: (ImageLoaderBlock) block {
    NSURL* url = [NSURL URLWithString: self.localURL];
    if ([url.scheme isEqualToString: @"file"]) {
        block([UIImage imageWithContentsOfFile: url.path], nil);
    } else if ([url.scheme isEqualToString: @"asset-library"]) {
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
            [assetslibrary assetForURL: url
                           resultBlock: resultblock
                          failureBlock: failureblock];
        }
    } else {
        NSLog(@"unhandled URL scheme %@", url.scheme);
        //XXX
        block(nil, nil);
    }
}
@end
