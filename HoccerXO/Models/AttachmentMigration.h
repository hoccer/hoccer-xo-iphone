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
+ (void) findOrphanedFilesAndRegisterAsAttachment;

@end
