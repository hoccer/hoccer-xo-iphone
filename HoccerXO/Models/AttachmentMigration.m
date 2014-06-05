//
//  AttachmentMigration.m
//  HoccerXO
//
//  Created by Guido Lorenz on 05.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AttachmentMigration.h"

#import <AVFoundation/AVFoundation.h>

#import "AppDelegate.h"
#import "Attachment.h"

@implementation AttachmentMigration

+ (void) determinePlayabilityForAllAudioAttachments {
    AppDelegate *delegate = [AppDelegate instance];

    NSManagedObjectModel *managedObjectModel = delegate.managedObjectModel;
    NSManagedObjectContext *managedObjectContext = delegate.managedObjectContext;

    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestTemplateForName:@"AudioAttachmentsWithUnknownPlayability"];
    NSArray *attachments = [managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    for (Attachment *attachment in attachments) {
        [attachment determinePlayability];
    }
}

@end
