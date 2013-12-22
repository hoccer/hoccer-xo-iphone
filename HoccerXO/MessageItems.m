//
//  MessageItem.m
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageItems.h"
#import "HXOMessage.h"
#import "Attachment.h"
#import "HXOHyperLabel.h"

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
        self.message = message;
    }
    return self;
}

- (NSAttributedString*) attributedBody {
    if ( ! _attributedBody && [self.message.body length] > 0) {
        _attributedBody = [self messageBodyWithLinks];
    }
    return _attributedBody;
}

- (NSAttributedString*) messageBodyWithLinks {
    NSMutableAttributedString * body = [[NSMutableAttributedString alloc] initWithString: self.message.body];
    [body addLinksMatching: _linkDetector];
    return body;
}

@end
