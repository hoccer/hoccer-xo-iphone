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

#import <MobileCoreServices/MobileCoreServices.h>

#define DEBUG_MIGRATION NO

@implementation AttachmentMigration

+ (void)adoptOrphanedFile:(NSString*)file inDirectory:(NSURL*)inDirectory {
    NSLog(@"orphaned file: %@", file);
    
    if ([[file substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"."]) {
        NSLog(@"Ignoring file starting with dot: %@",file);
        return;
    }
    
    NSString * extension = [file pathExtension];
    NSString * fullPath = [[inDirectory path] stringByAppendingPathComponent:file];
    NSURL * fullURL = [NSURL fileURLWithPath:fullPath];
    
    NSDictionary * attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
    if (attributes != nil && [attributes objectForKey:NSFileSize] != nil) {
        BOOL isDirectory = [[attributes fileType] isEqualToString:NSFileTypeDirectory];
        
        if (!isDirectory && extension.length > 0 && [attributes fileSize] > 0) {
            NSString * uti = [Attachment UTIFromfileExtension:extension];
            NSString * mediaType = [AppDelegate mediaTypeOfUTI:uti];
            NSString * mimeType = [Attachment mimeTypeFromUTI:uti];
            NSString * localURL = [fullURL absoluteString];
            
            // better to run this on main thread because it will generate previews and possible trigger observers
            // seen the asset stuff causing problem when invoking from background thread
            [AppDelegate.instance performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                NSLog(@"Making attachment for orphaned file %@ mediaType %@ mimeType %@ url %@", file, mediaType, mimeType, localURL);
#define ARMED
#ifdef ARMED
                [Attachment makeAttachmentWithMediaType:mediaType mimeType:mimeType humanReadableFileName:file localURL:localURL assetURL:nil inContext:context whenReady:^(Attachment * attachment, NSError * error) {
                    NSLog(@"Finished making attachment %@, error=%@",attachment, error);
                    [attachment determinePlayability];
                }];
#endif
            }];
        } else {
            NSLog(@"Ignoring file with zero size or no extension: %@",file);
        }
    }
}

+ (void) adoptOrphanedFiles:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory {
    AppDelegate *delegate = [AppDelegate instance];
    
    [delegate performWithoutLockingInNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        // fetch
        NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:entity];
        NSArray *attachments = [context executeFetchRequest:fetchRequest error:nil];
        
        NSMutableSet * attachmentFiles = [NSMutableSet new];
        NSMutableDictionary * attachmentsByFile = [NSMutableDictionary new];
        for (Attachment * attachment in attachments) {
            NSURL * attachmentURL = [attachment contentURL];
            if ([attachmentURL isFileURL]) {
                if (DEBUG_MIGRATION) NSLog(@"Attachment owns file %@ playable %@", attachmentURL, attachment.playable);
                NSString * file = [attachmentURL lastPathComponent];
                [attachmentFiles addObject:file];
                attachmentsByFile[file] = attachment;
            }
        }
        
        //NSURL * documentDirectory = [AppDelegate.instance applicationDocumentsDirectory];
        
        //NSArray * files = [AppDelegate fileNamesInDirectoryAtURL:documentDirectory ignorePaths:@[@"credentials.json", @"default.hciarch", @"._.DS_Store", @".DS_Store"] ignoreSuffixes:@[]];
        NSMutableSet * orphanedFilesSet = [NSMutableSet setWithArray:newFiles];
        [orphanedFilesSet addObjectsFromArray:changedFiles];
        [orphanedFilesSet minusSet:attachmentFiles];
        
        NSMutableSet * orphanedAttachmentsSet = [NSMutableSet setWithSet:attachmentFiles];
        [orphanedAttachmentsSet minusSet:[NSSet setWithArray:allFiles]];
        
        NSLog(@"Total attachments: %lu, orphaned attachments: %lu, total files: %lu, orphaned files:%lu", (unsigned long)attachmentFiles.count, (unsigned long)orphanedAttachmentsSet.count, (unsigned long)allFiles.count, (unsigned long)orphanedFilesSet.count);
        
        for (NSString * file in orphanedFilesSet) {
            [self adoptOrphanedFile:file inDirectory:inDirectory];
        }
        
        NSMutableArray * orphanedAttachments = [NSMutableArray new];
        for (NSString * attachmentFile in orphanedAttachmentsSet) {
            NSLog(@"orphaned attachments: %@", attachmentFile);
            [orphanedAttachments addObject:attachmentsByFile[attachmentFile]];
        }
        [AppDelegate.instance saveContext:context];
        [AppDelegate.instance performAfterCurrentContextFinishedInMainContextPassing:orphanedAttachments
                                                                           withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                                                               for (Attachment * attachment in managedObjects) {
                                                                                   NSLog(@"Deleting orphaned attachment object pointing to %@", attachment.contentURL);
#ifdef ARMED
                                                                                   [AppDelegate.instance deleteObject:attachment inContext:context];
#endif
                                                                               }
                                                                           }];
    }];
}


+ (void) determinePlayabilityForAllAudioAttachments {
    AppDelegate *delegate = [AppDelegate instance];

    NSManagedObjectModel *managedObjectModel = delegate.managedObjectModel;
    NSManagedObjectContext *mainObjectContext = delegate.mainObjectContext;

    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestTemplateForName:@"AudioAttachmentsWithUnknownPlayability"];
    NSArray *attachments = [mainObjectContext executeFetchRequest:fetchRequest error:nil];
    
    for (Attachment *attachment in attachments) {
        [attachment determinePlayability];
    }
}

@end
