//
//  EncryptingInputStream.m
//  EncryptingInputStream
//
//  Created by Pavel Mayer 17.4.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//  Based on a demo from http://bjhomer.blogspot.de/2011/04/subclassing-nsinputstream.html
//

#import "CryptingInputStream.h"
#import "HXOUserDefaults.h"

#define CRYPTO_STREAM_DEBUG ([[self verbosityLevel]isEqualToString:@"trace"])

@implementation CryptingInputStream 
{
	NSInputStream *parentStream;
	id <NSStreamDelegate> delegate;
	
	CFReadStreamClientCallBack copiedCallback;
	CFStreamClientContext copiedContext;
	CFOptionFlags requestedEvents;
    NSMutableData * restBuffer;
    NSStreamStatus thisStreamStatus;
    NSError * thisStreamError;
    NSInteger totalBytesIn;
    NSInteger totalBytesOut;
    NSInteger totalBytesSkipped;
    NSInteger skipBytes;
    NSString * _verbosityLevel;
}

@synthesize cryptoEngine = _cryptoEngine;

- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"cryptingInputStreamVerbosity"];
    }
    return _verbosityLevel;
}

#pragma mark Object lifecycle

- (id)initWithInputStream:(NSInputStream *)stream cryptoEngine:(CryptoEngine*)engine skipOutputBytes:(NSInteger)skipOutputBytes {
    {
        self = [super init];
        if (self) {
            // Initialization code here.
            _cryptoEngine = engine;
            parentStream = stream;
            [parentStream setDelegate:self];
            thisStreamStatus = NSStreamStatusNotOpen;
            restBuffer = [[NSMutableData alloc] init];
            totalBytesIn = 0;
            totalBytesOut = 0;
            totalBytesSkipped = 0;
            skipBytes = skipOutputBytes;
            [self setDelegate:self];
        }
        
        return self;
    }
}


- (void)dealloc
{
}

#pragma mark NSStream subclass methods

- (void)open {
    [self setThisStreamStatus:NSStreamStatusOpening];
	[parentStream open];
    [self setThisStreamStatus:NSStreamStatusOpen];
}

- (void)close {
    [self setThisStreamStatus:NSStreamStatusClosed];
	[parentStream close];
}

- (id <NSStreamDelegate> )delegate {
	return delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate {
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream setDelegate %@", aDelegate);}
	if (aDelegate == nil) {
		delegate = self;
	}
	else {
		delegate = aDelegate;
	}
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	[parentStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	[parentStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (id)propertyForKey:(NSString *)key {
	return [parentStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
	return [parentStream setProperty:property forKey:key];
}

- (NSStreamStatus)streamStatus {
    if (_cryptoEngine == nil) {
        return [parentStream streamStatus];
    }
    return thisStreamStatus;
}

- (void) setThisStreamStatus:(NSStreamStatus)theNewStatus {
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"setThisStreamStatus from %d to %d", thisStreamStatus,theNewStatus);}
    if (theNewStatus != thisStreamStatus) {
        thisStreamStatus = theNewStatus;
        switch (thisStreamStatus) {
            case NSStreamStatusOpen:
                [delegate stream:self handleEvent:NSStreamEventOpenCompleted];
                [delegate stream:self handleEvent:NSStreamEventHasBytesAvailable];
               break;
            case NSStreamStatusAtEnd:
                [delegate stream:self handleEvent:NSStreamEventEndEncountered];
                break;
            case NSStreamStatusError:
                [delegate stream:self handleEvent:NSStreamEventErrorOccurred];
                break;
            default:
                break;
        }
    }
}

- (NSError *)streamError {
    if (_cryptoEngine == nil) {
        return [parentStream streamError];
    }
    return thisStreamError;
}

#pragma mark NSInputStream subclass methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    // shortcut for the normal case
    if (skipBytes == 0 || totalBytesSkipped >= skipBytes) {
        return [self do_read:buffer maxLength:len];
    }
    
    // skip blockwise first
    const NSInteger blockSize = 65536;
    NSInteger blocksToSkip = skipBytes / blockSize;
    NSInteger blockSkipSize = blocksToSkip * blockSize;
    totalBytesSkipped = 0;
    NSMutableData * myBlockSkipData = [NSMutableData dataWithLength:blockSize];
    void * myBuffer = [myBlockSkipData mutableBytes];
    
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"NSInputStream: skipBytes=%d, blocksToSkip=%d, blockSkipSize=%d", skipBytes, blocksToSkip, blockSkipSize);}
    while (totalBytesSkipped < blockSkipSize) {
        NSInteger skipped = [self do_read:myBuffer maxLength:blockSize];
        if (skipped <= 0) {
            return skipped;
        }
        totalBytesSkipped += skipped;
    }
    // skip rest now
    NSInteger restToSkip = skipBytes - totalBytesSkipped;
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"NSInputStream: skipBytes=%d, blocksToSkip=%d, blockSkipSize=%d, totalBytesSkipped=%d, restToSkip=%d", skipBytes, blocksToSkip, blockSkipSize,totalBytesSkipped,restToSkip);}
    if (restToSkip <= blockSize) {
        if (restToSkip > 0) {
            NSInteger skipped = [self do_read:myBuffer maxLength:restToSkip];
            if (skipped < restToSkip) {
                return 0;
            }
            totalBytesSkipped += skipped;
        }
    } else {
        NSLog(@"#ERROR: restToSkip > blocksize, should not happen");
        return 0;
    }
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"NSInputStream: skipBytes=%d, totalBytesSkipped=%d", skipBytes, totalBytesSkipped);}
    return [self do_read:buffer maxLength:len];
}

- (NSInteger)do_read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: read len = %d, restBuffer = %d, status = %d, parentStreamStatus = %d", len, restBuffer.length, self.streamStatus, parentStream.streamStatus);}
    
    if (_cryptoEngine == nil) {
        NSInteger bytesRead = [parentStream read:buffer maxLength:len];
        if (bytesRead > 0) {
            totalBytesOut += bytesRead;
            totalBytesIn += bytesRead;
        }
        return bytesRead;
    }
    if (thisStreamStatus == NSStreamStatusError) {
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: returning -1 because of NSStreamStatusError");}
        return -1;
    }
    if (thisStreamStatus == NSStreamStatusAtEnd) {
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: returning 0 because of NSStreamStatusAtEnd");}
        return 0;
    }
    if (restBuffer.length < len) {
        // read more bytes from input stream
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: restBuffer.length = %d < len=%d", restBuffer.length, len);}
        // NOTE: when read delivers less bytes than requested, the http stream assumes we are exhausted, so we must not let this happen and always read one block more
        // The chosen value 16 however is only sufficient for up to 256 Bit cipher block sizes (AES 256 has 128)
        NSMutableData * mySourceData =[NSMutableData dataWithLength:len+32];
        NSInteger bytesRead = [parentStream read:[mySourceData mutableBytes] maxLength:len+32];
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: request %d bytes from parent, got %d, parentStatus = %d", len+16, bytesRead, parentStream.streamStatus);}
        if (bytesRead < 0) {
            thisStreamError = parentStream.streamError;
            [self setThisStreamStatus:NSStreamStatusError];
            NSLog(@"Error in EncrypingInputStream while reading plaintext stream%@", thisStreamError);
            return bytesRead;
        }
        // encrypt them
        NSError * myError = nil;
        NSData * myTransformedData = nil;
        if (bytesRead > 0) {
            totalBytesIn += bytesRead;
            [mySourceData setLength:bytesRead];
            myTransformedData = [_cryptoEngine addData:mySourceData error:&myError];
        }
        if (parentStream.streamStatus == NSStreamStatusAtEnd) {
            NSData * myFinalTransformedData = [_cryptoEngine finishWithError:&myError];
            NSMutableData * myTransformedMutableData = [NSMutableData dataWithData:myTransformedData];
            [myTransformedMutableData appendData:myFinalTransformedData];
            myTransformedData = myTransformedMutableData;
        }
        if (myError != nil) {
            NSLog(@"Error in EncrypingInputStream: %@", thisStreamError);
            [self setThisStreamStatus:NSStreamStatusError];
            thisStreamError = myError;
            return -1;
        }
        [restBuffer appendData:myTransformedData];
    }
    if (restBuffer.length >= len) {
        // satisfy read from rest buffer
        [restBuffer getBytes:buffer length:len];
        [restBuffer replaceBytesInRange:NSMakeRange(0, len) withBytes:nil length:0];
        totalBytesOut+= len;
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: totalIn=%d totalOut=%d returning len=%d", totalBytesIn, totalBytesOut, len);}
        return len;
    }
    // not enough to satisfy full reqeuested len, but hand the whole restbuffer we got if any
    [restBuffer getBytes:buffer length:restBuffer.length];
    NSInteger bytesOut = restBuffer.length;
    if (parentStream.streamStatus == NSStreamStatusAtEnd) {
        [self setThisStreamStatus:NSStreamStatusAtEnd];
    }
    [restBuffer setLength:0];
    totalBytesOut += bytesOut;
    if (CRYPTO_STREAM_DEBUG) {NSLog(@"CryptingInputStream: totalIn=%d totalOut=%d returning rest len=%d", totalBytesIn, totalBytesOut, bytesOut);}
	return bytesOut;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	// We cannot implement our character-counting in O(1) time,
	// so we return NO as indicated in the NSInputStream
	// documentation.
	return NO;
}

- (BOOL)hasBytesAvailable {
	return [parentStream hasBytesAvailable] || restBuffer.length > 0;
}

#pragma mark Undocumented CFReadStream bridged methods

- (void)_scheduleInCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {

	CFReadStreamScheduleWithRunLoop((CFReadStreamRef)parentStream, aRunLoop, aMode);
}

- (BOOL)_setCFClientFlags:(CFOptionFlags)inFlags
                 callback:(CFReadStreamClientCallBack)inCallback
                  context:(CFStreamClientContext *)inContext {
	
	if (inCallback != NULL) {
		requestedEvents = inFlags;
		copiedCallback = inCallback;
		memcpy(&copiedContext, inContext, sizeof(CFStreamClientContext));
		
		if (copiedContext.info && copiedContext.retain) {
			copiedContext.retain(copiedContext.info);
		}
	}
	else {
		requestedEvents = kCFStreamEventNone;
		copiedCallback = NULL;
		if (copiedContext.info && copiedContext.release) {
			copiedContext.release(copiedContext.info);
		}
		
		memset(&copiedContext, 0, sizeof(CFStreamClientContext));
	}
	
	return YES;	
}

- (void)_unscheduleFromCFRunLoop:(CFRunLoopRef)aRunLoop forMode:(CFStringRef)aMode {

	CFReadStreamUnscheduleFromRunLoop((CFReadStreamRef)parentStream, aRunLoop, aMode);
}

#pragma mark NSStreamDelegate methods

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
	
	if (aStream == parentStream) {
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"Parentstream encountered stream event %d", eventCode);}
    } else if (aStream == self) {
        if (CRYPTO_STREAM_DEBUG) {NSLog(@"Stream encountered stream event %d", eventCode);}
        
        switch (eventCode) {
            case NSStreamEventOpenCompleted:
                if (requestedEvents & kCFStreamEventOpenCompleted) {
                    copiedCallback((__bridge CFReadStreamRef)self,
                                   kCFStreamEventOpenCompleted,
                                   copiedContext.info);
                }
                break;
                
            case NSStreamEventHasBytesAvailable:
                if (requestedEvents & kCFStreamEventHasBytesAvailable) {
                    copiedCallback((__bridge CFReadStreamRef)self,
                                   kCFStreamEventHasBytesAvailable,
                                   copiedContext.info);
                }
                break;
                
            case NSStreamEventErrorOccurred:
                if (requestedEvents & kCFStreamEventErrorOccurred) {
                    copiedCallback((__bridge CFReadStreamRef)self,
                                   kCFStreamEventErrorOccurred,
                                   copiedContext.info);
                }
                break;
                
            case NSStreamEventEndEncountered:
                if (requestedEvents & kCFStreamEventEndEncountered) {
                    copiedCallback((__bridge CFReadStreamRef)self,
                                   kCFStreamEventEndEncountered,
                                   copiedContext.info);
                }
                break;
                
            case NSStreamEventHasSpaceAvailable:
                // This doesn't make sense for a read stream
                break;
                
            default:
                break;
        }
    }
}


@end
