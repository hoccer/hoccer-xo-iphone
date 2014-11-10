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
#define DEBUG_DUPLICATES NO

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
            NSString * mediaType = [AppDelegate mediaTypeOfUTI:uti withFileName:file];
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
        
        NSMutableArray * brokenAttachments = [NSMutableArray new];
        NSMutableSet * attachmentFiles = [NSMutableSet new];
        NSMutableDictionary * attachmentsByFile = [NSMutableDictionary new];
        NSMutableDictionary * attachmentsByURL = [NSMutableDictionary new]; // for non-file url duplicate detection
        NSMutableDictionary * attachmentsByMAC = [NSMutableDictionary new]; // for HMAC duplicate detection
        
        unsigned long fileDuplicates = 0;
        unsigned long macDuplicates = 0;
        unsigned long urlDuplicates = 0;
        for (Attachment * attachment in attachments) {
            NSURL * attachmentURL = [attachment contentURL];
            
            BOOL fileDuplicate = NO;
            BOOL urlDuplicate = NO;
            if ([attachmentURL isFileURL]) {
                if (DEBUG_MIGRATION) NSLog(@"Attachment owns file %@ playable %@", attachmentURL, attachment.playable);
                NSString * file = [attachmentURL lastPathComponent];
                if (attachmentsByFile[file] == nil) {
                    [attachmentFiles addObject:file];
                    attachmentsByFile[file] = attachment;
                } else {
                    // we have a duplicate
                    fileDuplicate = YES;
                    ++fileDuplicates;
                }
            } else {
                // handle non-URL-duplicate detection
                NSString * urlString = [[attachment contentURL] absoluteString];
                if (urlString != nil) {
                    if (attachmentsByURL[urlString] == nil) {
                        attachmentsByURL[urlString] = attachment;
                     } else {
                        urlDuplicate = YES;
                         ++urlDuplicates;
                     }
                } else {
                    BOOL oldEnough = NO;
                    if (attachment.creationDate == nil) {
                        oldEnough = YES;
                    } else {
                        NSTimeInterval attachmentAge = -[attachment.creationDate timeIntervalSinceNow];
                        oldEnough = attachmentAge > 60;
                    }
                    if (attachment.message == nil && oldEnough) {
                        NSLog(@"adding for deletion attachment without message and content: %@", attachment);
                        [brokenAttachments addObject:attachment];
                    }
                }
            }
            BOOL macDuplicate = NO;
            if (!fileDuplicate && !urlDuplicate) {
                // check for hmac duplicate
                NSData * hmac = nil;
                if (attachment.sourceMAC != nil && attachment.sourceMAC.length>0) {
                    hmac = attachment.sourceMAC;
                } else if (attachment.destinationMAC != nil && attachment.destinationMAC.length>0) {
                    hmac = attachment.destinationMAC;
                }
                if (hmac != nil) {
                    if (attachmentsByMAC[hmac] == nil) {
                        attachmentsByMAC[hmac] = attachment;
                    } else {
                        macDuplicate = YES;
                        ++macDuplicates;
                    }
                }
            }
            if (fileDuplicate || urlDuplicate || macDuplicate) {
                if (![attachment.duplicate isEqualToString:@"YESDUP"]) {
                    attachment.duplicate = @"YESDUP";
                    // we remember duplicates in the dictionary
                    NSLog(@"marked duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                } else {
                    if (DEBUG_DUPLICATES) NSLog(@"found duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                }
            } else {
                if (![attachment.duplicate isEqualToString:@"NODUP"]) {
                    NSLog(@"unmarking duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                    attachment.duplicate = @"NODUP";
                }
            }

        }
        NSLog(@"fileDuplicates: %lu, urlDuplicates: %lu, macDuplicates: %lu", fileDuplicates, urlDuplicates, macDuplicates);
        //NSURL * documentDirectory = [AppDelegate.instance applicationDocumentsDirectory];
        
        //NSArray * files = [AppDelegate fileNamesInDirectoryAtURL:documentDirectory ignorePaths:@[@"credentials.json", @"default.hciarch", @"._.DS_Store", @".DS_Store"] ignoreSuffixes:@[]];
        
        // find files with no attachment pointing to them
        NSMutableSet * orphanedFilesSet = [NSMutableSet setWithArray:newFiles];
        [orphanedFilesSet addObjectsFromArray:changedFiles];
        [orphanedFilesSet minusSet:attachmentFiles];
        
        // find attachments with an URL where no file exists
        NSMutableSet * orphanedAttachmentsSet = [NSMutableSet setWithSet:attachmentFiles];
        [orphanedAttachmentsSet minusSet:[NSSet setWithArray:allFiles]];
        
        NSLog(@"Total attachments: %lu, total attached files: %lu, duplicates = %lu, orphaned attachments: %lu, broken attachments: %lu, total files: %lu, orphaned files:%lu", (unsigned long)attachments.count, (unsigned long)attachmentFiles.count, (unsigned long)attachments.count - (unsigned long)attachmentFiles.count,(unsigned long)orphanedAttachmentsSet.count, (unsigned long)brokenAttachments.count, (unsigned long)allFiles.count, (unsigned long)orphanedFilesSet.count);
        
        for (NSString * file in orphanedFilesSet) {
            [self adoptOrphanedFile:file inDirectory:inDirectory];
        }
        
        NSMutableArray * orphanedAttachments = [NSMutableArray new];
        for (NSString * attachmentFile in orphanedAttachmentsSet) {
            NSLog(@"orphaned attachments: %@", attachmentFile);
            [orphanedAttachments addObject:attachmentsByFile[attachmentFile]];
        }
        [AppDelegate.instance saveContext:context];
        if (orphanedAttachments.count > 0) {
            [AppDelegate.instance performAfterCurrentContextFinishedInMainContextPassing:orphanedAttachments
                                                                               withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                                                                   for (Attachment * attachment in managedObjects) {
                                                                                       NSLog(@"Deleting orphaned attachment object pointing to %@", attachment.contentURL);
                                                                                       [AppDelegate.instance deleteObject:attachment inContext:context];
                                                                                   }
                                                                               }];
        }
        if (brokenAttachments.count > 0) {
            [AppDelegate.instance performAfterCurrentContextFinishedInMainContextPassing:brokenAttachments
                                                                               withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                                                                   for (Attachment * attachment in managedObjects) {
                                                                                       NSLog(@"Deleting broken attachment object pointing to %@", attachment.contentURL);
                                                                                       [AppDelegate.instance deleteObject:attachment inContext:context];
                                                                                   }
                                                                               }];
        }
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
