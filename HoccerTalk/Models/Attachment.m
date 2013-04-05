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

@dynamic uploadURL;
@dynamic uploadedSize;

@dynamic downloadURL;
@dynamic downloadedSize;

@dynamic message;

@synthesize image;

@synthesize uploadConnection;


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

- (void) assetDataLoader: (DataSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        NSError * myError = nil;
        int64_t mySize = [rep size];
        Byte *buffer = (Byte *)malloc(mySize);
        NSUInteger bufferLen = [rep getBytes: buffer fromOffset:0 length:mySize error:&myError];
        NSData * myData = [NSData dataWithBytesNoCopy: buffer length: bufferLen];
        block(myData, myError);
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


-(void) withUploadData: (DataSetterBlock) execution {
    if (self.localURL != nil) {
        NSLog(@"Attachment uploadData self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:myPath];
        NSLog(@"Attachment return uploadData len=%d, path=%@", [data length], myPath);
        execution(data, nil); // TODO: error handling
        return;
    }
    if (self.assetURL != nil) {
        NSLog(@"Attachment uploadData assetURL=%@", self.assetURL);
        [self assetDataLoader: execution url: self.assetURL];
        return;
    }
    execution(nil, [NSError errorWithDomain:@"HoccerTalk" code:1000 userInfo: nil]);
}

-(NSDictionary*) uploadHttpHeaders {
    NSString * myPath = nil;
    if (self.localURL != nil) {
        myPath = [[NSURL URLWithString: self.localURL] path];
    } else {
        myPath = @"unknown";
    }
	
    NSString *contentDisposition = [NSString stringWithFormat:@"attachment; filename=\"%@\"", myPath];
    NSDictionary * headers = [NSDictionary dictionaryWithObjectsAndKeys:
                              contentDisposition, @"Content-Disposition",
                              [NSString stringWithFormat:@"%lli", [self contentSize]], @"Content-Length",
                              nil
                   ];
    return headers;
    
}

// connection delegate methods

- (id < NSURLConnectionDelegate >) uploadDelegate {
    return self;
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == uploadConnection) {
        NSLog(@"Attachment uploadConnection didReceiveResponse %@, status=%ld, %@",
              httpResponse, (long)[httpResponse statusCode],
              [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
    } else {
        NSLog(@"ERROR: Attachment uploadConnection didReceiveResponse without valid connection");        
    }
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == uploadConnection) {
        NSLog(@"Attachment uploadConnection didReceiveData %@", data);
    } else {
        NSLog(@"ERROR: Attachment uploadConnection didReceiveResponse without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == uploadConnection) {
        NSLog(@"Attachment uploadConnection didSendBodyData %d", bytesWritten);
        self.uploadedSize = totalBytesWritten;
    } else {
        NSLog(@"ERROR: Attachment uploadConnection didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == uploadConnection) {
        NSLog(@"Attachment uploadConnection didFailWithError %@", error);
        self.uploadConnection = nil;
    } else {
        NSLog(@"ERROR: Attachment uploadConnection didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == uploadConnection) {
        NSLog(@"Attachment uploadConnection connectionDidFinishLoading %@", connection);
        self.uploadConnection = nil;
    } else {
        NSLog(@"ERROR: Attachment uploadConnection connectionDidFinishLoading without valid connection");
    }
}


@end
