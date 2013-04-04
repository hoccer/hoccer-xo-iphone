//
//  Attachment.m
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "Message.h"


@implementation Attachment

@dynamic localURL;
@dynamic mimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic contentSize;

@dynamic message;

- (UIImage *) symbolImage {
    return nil;
}

@end
