//
//  EncryptingInputStream.m
//  EncryptingInputStream
//
//  Created by Pavel Mayer 17.4.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//  Based on a demo from http://bjhomer.blogspot.de/2011/04/subclassing-nsinputstream.html
//

#import "EncryptingInputStream.h"


@implementation EncryptingInputStream 
{
	NSInputStream *parentStream;
	id <NSStreamDelegate> delegate;
	
	CFReadStreamClientCallBack copiedCallback;
	CFStreamClientContext copiedContext;
	CFOptionFlags requestedEvents;
    NSMutableData * restBuffer;
    NSStreamStatus thisStreamStatus;
    NSError * thisStreamError;
}

@synthesize cryptoEngine = _cryptoEngine;

#pragma mark Object lifecycle

- (id)initWithInputStreamAndEngine:(NSInputStream *)stream cryptoEngine:(CryptoEngine*)engine {
{
    self = [super init];
    if (self) {
        // Initialization code here.
        _cryptoEngine = engine;
		parentStream = stream;
		[parentStream setDelegate:self];
        thisStreamStatus = NSStreamStatusNotOpen;
        restBuffer = [[NSMutableData alloc] init];
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
    thisStreamStatus = NSStreamStatusOpening;
	[parentStream open];
    thisStreamStatus = NSStreamStatusOpen;
}

- (void)close {
    thisStreamStatus = NSStreamStatusClosed;
	[parentStream close];
}

- (id <NSStreamDelegate> )delegate {
	return delegate;
}

- (void)setDelegate:(id<NSStreamDelegate>)aDelegate {
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

- (NSError *)streamError {
    if (_cryptoEngine == nil) {
        return [parentStream streamError];
    }
    return thisStreamError;
}

#pragma mark NSInputStream subclass methods

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (_cryptoEngine == nil) {
        return [parentStream read:buffer maxLength:len];
    }
    if (thisStreamStatus == NSStreamStatusError) {
        return -1;
    }
    if (thisStreamStatus == NSStreamStatusAtEnd) {
        return 0;
    }
    if (restBuffer.length < len) {
        // read more bytes from input stream
        NSMutableData * myPlaintext =[NSMutableData dataWithLength:len];
        NSInteger bytesRead = [parentStream read:[myPlaintext mutableBytes] maxLength:len];
        if (bytesRead < 0) {
            thisStreamError = parentStream.streamError;
            thisStreamStatus = NSStreamStatusError;
            NSLog(@"Error in EncrypingInputStream while reading plaintext stream%@", thisStreamError);
            return bytesRead;
        }
        // encrypt them
        NSError * myError = nil;
        NSData * myCiphertext = nil;
        if (bytesRead > 0) {
            [myPlaintext setLength:bytesRead];
            myCiphertext = [_cryptoEngine addData:myPlaintext error:&myError];
        } else {
            // byteRead == 0
            myCiphertext = [_cryptoEngine finishWithError:&myError];
        }
        if (myError != nil) {
            NSLog(@"Error in EncrypingInputStream: %@", thisStreamError);
            thisStreamStatus = NSStreamStatusError;
            thisStreamError = myError;
            return -1;
        }
        [restBuffer appendData:myCiphertext];
    }
    if (restBuffer.length <= len) {
        // satisfy read from rest buffer
        [restBuffer getBytes:buffer length:len];
        [restBuffer replaceBytesInRange:NSMakeRange(0, len) withBytes:nil length:0];
        return len;
    }
    // hand out whole restbuffer
    [restBuffer getBytes:buffer length:restBuffer.length];
    thisStreamStatus = NSStreamStatusAtEnd;
    NSInteger bytesRead = restBuffer.length;
    [restBuffer setLength:0];
	return bytesRead;
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
	
	assert(aStream == parentStream);
	
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


@end
