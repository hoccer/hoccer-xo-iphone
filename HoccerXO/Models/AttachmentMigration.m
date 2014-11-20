//
//  AttachmentMigration.m
//  HoccerXO
//
//  Created by Guido Lorenz on 05.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AttachmentMigration.h"
#import "AppDelegate.h"
#import "Attachment.h"
#import "NSData+HexString.h"

#import <AVFoundation/AVFoundation.h>
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

static BOOL isOldAttachment(Attachment * attachment) {
    BOOL oldEnough = NO;
    if (attachment.creationDate == nil) {
        oldEnough = YES;
    } else {
        NSTimeInterval attachmentAge = -[attachment.creationDate timeIntervalSinceNow];
        NSLog(@"attachmentAge = %f", attachmentAge);
        oldEnough = attachmentAge > 600;
    }
    return oldEnough;
}

static BOOL qualifiesForDeletion(Attachment * attachment) {
    return ![attachment isDeleted] && ![attachment isInserted] && isOldAttachment(attachment) && !attachment.outgoing && !attachment.incoming && !attachment.uploadable && !attachment.downloadable;
}

static NSURL * significantURL(Attachment * attachment) {
    NSURL * attachmentURL = [NSURL URLWithString: attachment.ownedURL];
    if (attachmentURL == nil) {
        attachmentURL = attachment.contentURL;
    }
    return attachmentURL;
}

static NSString * filenameOf(Attachment * attachment) {
    NSURL * fullName = significantURL(attachment);
    return [fullName lastPathComponent];
}


+ (void) adoptOrphanedFiles:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory {
    AppDelegate *delegate = [AppDelegate instance];
    
    [delegate performWithLockingId:@"adoptOrphanedFiles" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        
        NSSet * allFilesSet = [NSSet setWithArray:allFiles];

        // fetch
        NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:entity];
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"orderNumber" ascending:YES];
        NSArray *sortDescriptors = @[sortDescriptor];
        [fetchRequest setSortDescriptors:sortDescriptors];
        NSArray *attachments = [context executeFetchRequest:fetchRequest error:nil];
        
        NSMutableArray * brokenAttachments = [NSMutableArray new];
        NSMutableArray * danglingAttachments = [NSMutableArray new];
        
        //NSMutableSet * attachmentFiles = [NSMutableSet new];
        
        NSMutableDictionary * attachmentsByFile = [NSMutableDictionary new];
        NSMutableDictionary * attachmentsByURL = [NSMutableDictionary new]; // for non-file url duplicate detection
        NSMutableDictionary * attachmentsByMAC = [NSMutableDictionary new]; // for HMAC duplicate detection
        
        NSCountedSet * referencedFiles = [NSCountedSet new];
        NSCountedSet * referencedMACS = [NSCountedSet new];
        
        unsigned long fileDuplicates = 0;
        unsigned long macDuplicates = 0;
        unsigned long urlDuplicates = 0;
        
        // iterate over all attachments, mark duplicates and remember attachments owned by files
        long long order = 0;
        for (Attachment * attachment in attachments) {
            ++order;
            if (attachment.orderNumber.longLongValue != order) {
                NSLog(@"Changing order from %@ to %lld", attachment.orderNumber, order);
                attachment.orderNumber =@(order);
            }
            NSURL * attachmentURL = significantURL(attachment);
            if (DEBUG_MIGRATION)NSLog(@"Checking attachment %@, file %@", attachment.objectID.URIRepresentation, [attachmentURL lastPathComponent]);
            
            BOOL fileDuplicate = NO;
            BOOL urlDuplicate = NO;
            if ([attachmentURL isFileURL]) {
                
                if (DEBUG_MIGRATION) NSLog(@"Attachment owns file %@ playable %@", attachmentURL, attachment.playable);
                NSString * file = [attachmentURL lastPathComponent];
                [referencedFiles addObject:file];
                
                NSString * fullPath = [[inDirectory path] stringByAppendingPathComponent:file];
                
                if ([allFilesSet containsObject:file]) {
                    if (attachment.message != nil && attachment.available) {
                        if ([AppDelegate isUserReadWriteFile:fullPath]) {
                            [AppDelegate setPosixPermissionsReadOnlyForPath:fullPath];
                        }
                    } else {
                        if (![AppDelegate isUserReadWriteFile:fullPath]) {
                            [AppDelegate setPosixPermissionsReadWriteForPath:fullPath];
                        }
                    }
                    
                    if (attachmentsByFile[file] == nil) {
                        attachmentsByFile[file] = attachment;
                    } else {
                        // we have a duplicate
                        fileDuplicate = YES;
                        if (DEBUG_MIGRATION) NSLog(@"FILE duplicate # %lu", (unsigned long)[referencedFiles countForObject:file]);
                        ++fileDuplicates;
                    }
                } else {
                    // attachment without file
                    if ((attachment.message == nil && isOldAttachment(attachment)) || (attachment.message != nil && qualifiesForDeletion(attachment))) {
                        NSLog(@"adding broken attachment for deletion: %@", attachment);
                        [brokenAttachments addObject:attachment];
                    } else {
                        attachment.fileStatus = @"DOES_NOT_EXIST";
                        [danglingAttachments addObject:attachment];
                    }
                }
            } else {
                // handle non-file-URL-duplicate detection
                NSString * urlString = [attachmentURL absoluteString];
                if (urlString != nil) {
                    if (attachmentsByURL[urlString] == nil) {
                        attachmentsByURL[urlString] = attachment;
                     } else {
                        urlDuplicate = YES;
                         ++urlDuplicates;
                     }
                } else {
                    if (attachment.message == nil && isOldAttachment(attachment)) {
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
                    [referencedMACS addObject:hmac];
                    if (attachmentsByMAC[hmac] == nil) {
                        attachmentsByMAC[hmac] = attachment;
                    } else {
                        if (DEBUG_MIGRATION) NSLog(@"MAC duplicate # %lu (%@)", (unsigned long)[referencedMACS countForObject:hmac], [hmac hexadecimalString]);
                        macDuplicate = YES;
                        ++macDuplicates;
                    }
                }
            }
            if (fileDuplicate || urlDuplicate || macDuplicate) {
                if (![attachment.duplicate isEqualToString:@"DUPLICATE"]) {
                    attachment.duplicate = @"DUPLICATE";
                    // we remember duplicates in the dictionary
                    NSLog(@"marked duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                } else {
                    if (DEBUG_DUPLICATES) NSLog(@"found duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                }
            } else {
                if (![attachment.duplicate isEqualToString:@"ORIGINAL"]) {
                    NSLog(@"unmarking duplicate attachment for file: %@", [attachmentURL lastPathComponent]);
                    attachment.duplicate = @"ORIGINAL";
                }
            }
        }
        NSLog(@"fileDuplicates: %lu, urlDuplicates: %lu, macDuplicates: %lu", fileDuplicates, urlDuplicates, macDuplicates);
        
        // find new or changed files with no attachment pointing to them,
        // but consider only the files supplied in corresponding method arguments
        NSMutableSet * orphanedFilesSet = [NSMutableSet setWithArray:newFiles];
        [orphanedFilesSet addObjectsFromArray:changedFiles];
        [orphanedFilesSet minusSet:referencedFiles];
        
        NSLog(@"Total attachments: %lu, total attached files: %lu, duplicates = %lu, dangling attachments: %lu, broken attachments: %lu, total files: %lu, orphaned files:%lu", (unsigned long)attachments.count, (unsigned long)referencedFiles.count, (unsigned long)attachments.count - (unsigned long)referencedFiles.count,(unsigned long)danglingAttachments.count, (unsigned long)brokenAttachments.count, (unsigned long)allFiles.count, (unsigned long)orphanedFilesSet.count);
        
        for (NSString * file in orphanedFilesSet) {
            [self adoptOrphanedFile:file inDirectory:inDirectory];
        }
        
        [AppDelegate.instance saveContext:context];

        if (brokenAttachments.count > 0) {
            [AppDelegate.instance performAfterCurrentContextFinishedInMainContextPassing:brokenAttachments
                                                                               withBlock:^(NSManagedObjectContext *context, NSArray *managedObjects) {
                                                                                   for (Attachment * attachment in managedObjects) {
                                                                                       NSLog(@"Deleting broken attachment object pointing to %@", significantURL(attachment));
#ifdef ARMED
                                                                                       [AppDelegate.instance deleteObject:attachment inContext:context];
#endif
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
