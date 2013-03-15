//
//  ImageAttachment.h
//  HoccerTalk
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Attachment.h"

typedef void(^ImageLoaderBlock)(UIImage*,NSError*);

@interface ImageAttachment : Attachment

@property (nonatomic, retain) NSNumber * width;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic,readonly) CGFloat aspectRatio;

- (void) loadImage: (ImageLoaderBlock) block;

@end
