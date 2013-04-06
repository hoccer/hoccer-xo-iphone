//
//  Attachment.m
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "TalkMessage.h"
#import "HoccerTalkBackend.h"
#import "AppDelegate.h"

#import <Foundation/NSURL.h>
#import <MediaPlayer/MPMoviePlayerController.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>

@implementation Attachment

@dynamic localURL;
@dynamic mimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic contentSize;
@dynamic aspectRatio;

@dynamic remoteURL;
@dynamic transferSize;

@dynamic message;

@synthesize image;
@synthesize transferConnection = _transferConnection;
@synthesize chatBackend = _chatBackend;


+ (NSNumber *) fileSize: (NSString *) fileURL withError: (NSError**) myError {
    *myError = nil;
    NSString * myPath = [[NSURL URLWithString: fileURL] path];
    NSNumber * result =  @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:myError] fileSize]);
    if (*myError != nil) {
        NSLog(@"can not determine size of file '%@'", myPath);
        result = @(-1);
    }
    NSLog(@"Size = %@ (of file '%@')", result, myPath);
    return result;
}

- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }
    
    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;
    
}

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
        self.contentSize = [Attachment fileSize: self.localURL withError:&myError];
        /*
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        self.contentSize = @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:&myError] fileSize]);
        if (myError != nil) {
            NSLog(@"can not determine size of file '%@'", myPath);
        }
        NSLog(@"Size = %@ (of file '%@')", self.contentSize, myPath);
         */
    }
    if (self.assetURL != nil) {
        [self assetSizer:^(int64_t theSize, NSError * theError) {
            self.contentSize = @(theSize);
            NSLog(@"Asset Size = %@ (of file '%@')", self.contentSize, self.assetURL);
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
        
        if(self.assetURL && [self.assetURL length])
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

- (void) upload {
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        NSLog(@"upload of attachment still running");
        return;
    }
    [self withUploadData:^(NSData * myData, NSError * myError) {
        if (myError == nil) {
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                             absoluteURI:[self remoteURL]
                                                 payload:myData
                                                 headers:[self uploadHttpHeaders]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            
        } else {
            NSLog(@"uploadAttachment error=%@",myError);
        }
    }];
}

- (void) download {
    NSLog(@"downloadAttachment %@", self);
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoing = %@", self.message.isOutgoing);
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        NSLog(@"download of attachment still running");
        return;
    }
    
    if (self.ownedURL == nil) {
        // create new destination file for download
        NSURL *appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
        self.ownedURL = [self localUrlForDownloadinDirectory: appDocDir];
    } else {
        // until we use ranged requests, let us delete the file in case it is left over
        NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
    }
    
    NSLog(@"downloadAttachment: ownedURL = %@", self.ownedURL);
    NSLog(@"downloadAttachment: remoteURL = %@", self.remoteURL);
    
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                     absoluteURI:[self remoteURL]
                                         payload:nil
                                         headers:[self downloadHttpHeaders]
                                ];
    self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self downloadDelegate]];
}

- (void) downloadLater: (NSTimer*) theTimer {
    [self download];
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
                              [self contentSize].stringValue, @"Content-Length",
                              nil
                   ];
    return headers;
    
}

-(NSDictionary*) downloadHttpHeaders {
    return nil;
}

- (NSString *) localUrlForDownloadinDirectory: (NSURL *) theDirectory {
    NSString * myRemoteURL = [NSURL URLWithString: [self remoteURL]];
    NSString * myRemoteFileName = myRemoteURL.lastPathComponent;
    NSURL * myNewFile = [NSURL URLWithString:myRemoteFileName relativeToURL:theDirectory];
    NSString * myNewFilename = [[[myNewFile absoluteString] stringByAppendingString:@"." ] stringByAppendingString: [self fileExtensionFromMimeType]];
    return myNewFilename;
}

- (NSString *) fileExtensionFromMimeType {
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(self.mimeType), NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    return (__bridge NSString *)(extension);
}

// connection delegate methods

- (id < NSURLConnectionDelegate >) uploadDelegate {
    return self;
}

- (id < NSURLConnectionDelegate >) downloadDelegate {
    return self;
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == _transferConnection) {
        NSLog(@"Attachment transferConnection didReceiveResponse %@, status=%ld, %@",
              httpResponse, (long)[httpResponse statusCode],
              [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveResponse without valid connection");        
    }
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _transferConnection) {
        NSLog(@"Attachment transferConnection didReceiveData len=%lu", (unsigned long)[data length]);
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            NSURL * myURL = [NSURL URLWithString: self.ownedURL];
            NSString * myPath = [myURL path];
            NSOutputStream * stream = [[NSOutputStream alloc] initToFileAtPath: myPath append:YES];
            [stream open];
            NSUInteger left = [data length];
            NSUInteger nwr = 0;
            do {
                nwr = [stream write:[data bytes] maxLength:left];
                if (-1 == nwr) break;
                left -= nwr;
            } while (left > 0);
            if (left) {
                NSLog(@"ERROR: Attachment transferConnection didReceiveData, stream error: %@", [stream streamError]);
            }
            [stream close];
        } else {
            NSLog(@"ERROR: Attachment transferConnection didReceiveData on outgoing (upload) connection");
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == _transferConnection) {
        NSLog(@"Attachment transferConnection didSendBodyData %d", bytesWritten);
        self.transferSize = @(totalBytesWritten);
    } else {
        NSLog(@"ERROR: Attachment transferConnection didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == _transferConnection) {
        NSLog(@"Attachment transferConnection didFailWithError %@", error);
        self.transferConnection = nil;
    } else {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _transferConnection) {
        NSLog(@"Attachment transferConnection connectionDidFinishLoading %@", connection);
        self.transferConnection = nil;
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            // finish download
            NSError *myError = nil;
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];

            if ([self.transferSize isEqualToNumber: self.contentSize]) {
                NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully downloaded attachment, size=%@", self.contentSize);
                self.localURL = self.ownedURL;
                // TODO: maybe do some UI refresh here, or use an observer for this
            } else {
                NSLog(@"Attachment transferConnection connectionDidFinishLoading download failed, contentSize=%@, self.transferSize=%@", self.contentSize, self.transferSize);
                // TODO: trigger some retry
            }
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection connectionDidFinishLoading without valid connection");
    }
}

#pragma mark - Custom Getters and Setters

- (void) setContentSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"contentSize"];
    [self setPrimitiveValue: size forKey: @"contentSize"];
    [self didChangeValueForKey:@"contentSize"];
}

- (void) setTransferSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"transferSize"];
    [self setPrimitiveValue: size forKey: @"transferSize"];
    [self didChangeValueForKey:@"transferSize"];
}


@end
