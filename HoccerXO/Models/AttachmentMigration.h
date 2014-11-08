//
//  AttachmentMigration.h
//  HoccerXO
//
//  Created by Guido Lorenz on 05.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Attachment;

@interface AttachmentMigration : NSObject

+ (void) determinePlayabilityForAllAudioAttachments;
+ (void) adoptOrphanedFile:(NSString*)file inDirectory:(NSURL*)inDirectory;
+ (void) adoptOrphanedFiles:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory;

@end
