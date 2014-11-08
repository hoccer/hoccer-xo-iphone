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

/*

NSString *preferredUTIForExtension(NSString *ext) {
    NSString *theUTI = (__bridge_transfer NSString *)
    UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension, (__bridge CFStringRef) ext, NULL);
    return theUTI;
}

NSString *preferredUTIForMIMEType(NSString *mime) {
    NSString *theUTI = (__bridge_transfer NSString *)
    UTTypeCreatePreferredIdentifierForTag( kUTTagClassMIMEType, (__bridge CFStringRef) mime, NULL);
    return theUTI;
}

NSString *extensionForUTI(NSString *aUTI) {
    CFStringRef theUTI = (__bridge CFStringRef) aUTI;
    CFStringRef results = UTTypeCopyPreferredTagWithClass(theUTI, kUTTagClassFilenameExtension);
    return (__bridge_transfer NSString *)results;
}

NSString *mimeTypeForUTI(NSString *aUTI) {
    CFStringRef theUTI = (__bridge CFStringRef) aUTI;
    CFStringRef results = UTTypeCopyPreferredTagWithClass(theUTI, kUTTagClassMIMEType);
    return (__bridge_transfer NSString *)results;
}
*/
@implementation AttachmentMigration

+ (void) findOrphanedFilesAndRegisterAsAttachment {
    AppDelegate *delegate = [AppDelegate instance];
    
    [delegate performWithoutLockingInNewBackgroundContext:^(NSManagedObjectContext *context) {
        NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:entity];
        NSArray *attachments = [context executeFetchRequest:fetchRequest error:nil];
        
        NSMutableSet * attachmentFiles = [NSMutableSet new];
        NSMutableDictionary * attachmentsByFile = [NSMutableDictionary new];
        for (Attachment * attachment in attachments) {
            NSURL * attachmentURL = [attachment contentURL];
            if ([attachmentURL isFileURL]) {
                NSLog(@"Attachment owns file %@ playable %@", attachmentURL, attachment.playable);
                NSString * file = [attachmentURL lastPathComponent];
                [attachmentFiles addObject:file];
                attachmentsByFile[file] = attachment;
            }
        }
        
        NSArray * files = [AppDelegate fileNamesInDirectoryAtURL:[AppDelegate.instance applicationDocumentsDirectory] ignorePaths:@[@"credentials.json", @"default.hciarch", @"._.DS_Store", @".DS_Store"] ignoreSuffixes:@[]];
        NSMutableSet * orphanedFilesSet = [NSMutableSet setWithArray:files];
        [orphanedFilesSet minusSet:attachmentFiles];
        
        NSMutableSet * orphanedAttachmentsSet = [NSMutableSet setWithSet:attachmentFiles];
        [orphanedAttachmentsSet minusSet:[NSSet setWithArray:files]];
        
        NSLog(@"Total attachments: %lu, orphaned attachments: %lu, total files: %lu, orphaned files:%lu", (unsigned long)attachmentFiles.count, (unsigned long)orphanedAttachmentsSet.count, (unsigned long)files.count, (unsigned long)orphanedFilesSet.count);
        
        for (NSString * file in orphanedFilesSet) {
            NSLog(@"orphaned file: %@", file);
            NSString * extension = [file pathExtension];
            if (extension.length > 0) {
                NSString * uti = [Attachment UTIFromfileExtension:extension];
                NSString * mediaType = [AppDelegate mediaTypeOfUTI:uti];
                NSString * mimeType = [Attachment mimeTypeFromUTI:uti];
                NSString * fullPath = [[[AppDelegate.instance applicationDocumentsDirectory] path] stringByAppendingPathComponent:file];
                NSURL * fullURL = [NSURL fileURLWithPath:fullPath];
                NSString * localURL = [fullURL absoluteString];
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
            }
        }
        
        NSMutableArray * orphanedAttachments = [NSMutableArray new];
        for (NSString * attachmentFile in orphanedAttachmentsSet) {
            NSLog(@"orphaned attachments: %@", attachmentFile);
            [orphanedAttachments addObject:attachmentsByFile[attachmentFile]];
        }
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
