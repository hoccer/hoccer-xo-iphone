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

#import "UIImage+ScaleAndCrop.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>


#define DEBUG_MIGRATION NO
#define DEBUG_ORDER YES
#define DEBUG_DUPLICATES NO
#define DEBUG_QUERY NO
#define DEBUG_TIMING YES
#define DEBUG_MORE_TIMING YES

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
    
    if ([AppDelegate isBusyFile:fullPath]) {
        NSLog(@"Ignoring busy file : %@",file);
        return;
    }
    
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
            dispatch_sync(dispatch_get_main_queue(), ^{
            // [AppDelegate.instance performAfterCurrentContextFinishedInMainContext:^(NSManagedObjectContext *context) {
                NSLog(@"Making attachment for orphaned file %@ mediaType %@ mimeType %@ url %@", file, mediaType, mimeType, localURL);
#define ARMED
#ifdef ARMED
                [Attachment makeAttachmentWithMediaType:mediaType mimeType:mimeType humanReadableFileName:file localURL:localURL assetURL:nil inContext:AppDelegate.instance.mainObjectContext whenReady:^(Attachment * attachment, NSError * error) {
                    attachment.duplicate = @"ORIGINAL";
                    //NSLog(@"Finished making attachment %@, error=%@",attachment, error);
                    NSLog(@"Finished making attachment %@",attachment.humanReadableFileName);
                    [attachment determinePlayability];
                    attachment.previewImage = nil; // save memory
                    [AppDelegate.instance saveDatabase];
                }];
#endif
            //}];
            });

        } else {
            NSLog(@"Ignoring file with zero size or no extension: %@",file);
        }
    }
}

static BOOL isOldAttachment(Attachment * attachment) {

    BOOL inserted = attachment.isInserted;
    BOOL isTemporary = [[attachment objectID] isTemporaryID];
    if (inserted || isTemporary) {
        return NO;
    }
    BOOL oldEnough = NO;
    if (attachment.creationDate == nil) {
        oldEnough = YES;
    } else {
        NSTimeInterval attachmentAge = -[attachment.creationDate timeIntervalSinceNow];
        NSLog(@"attachmentAge = %f", attachmentAge);
        oldEnough = attachmentAge > 10;
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


// a function to create a lot of different images for performance testing
+ (void)makeSmallCloneImages:(Attachment*)attachment {
    [attachment loadPreviewImageIntoCacheWithCompletion:^(NSError *theError) {
        
        NSLog(@"makeSmallCloneImage %@", attachment.localURL);

        if (theError == nil) {
            UIImage * image = attachment.previewImage;
            NSString * newFileName = @"reduImage.jpg";
            if (attachment.humanReadableFileName.length > 2) {
                newFileName = attachment.humanReadableFileName;
            }
            while (image.size.width > 1 && image.size.height > 1) {
                image = [image imageScaledToSize:CGSizeMake(image.size.width/2, image.size.height/2)];
                
                newFileName = [NSString stringWithFormat:@"d2%@.jpeg", newFileName];
                NSURL * myURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
                
                [UIImageJPEGRepresentation(image,0.2) writeToURL:myURL atomically:NO];

                myURL = [AppDelegate moveDocumentToPermanentLocation:myURL];
                NSLog(@"New smaller image moved to %@", myURL);
            }
        }
    }];
}

+ (void) adoptOrphanedFiles:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory withAttachments:(NSArray *)attachments inContext:(NSManagedObjectContext *)context
{
    
    NSSet * allFilesSet = [NSSet setWithArray:allFiles];

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
    //long long order = 0;
    for (Attachment * attachment in attachments) {
        
        //[self makeSmallCloneImages:attachment];
        /*
        ++order;
        if (attachment.orderNumber == nil || attachment.orderNumber.longLongValue < order) {
            if (DEBUG_ORDER)NSLog(@"Changing order from %@ to %lld, file = %@", attachment.orderNumber, order, attachment.humanReadableFileName);
            attachment.orderNumber =@(order);
        } else {
            order = attachment.orderNumber.longLongValue;
        }
         */
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
                // set new field for older databases
                if (attachment.entityTag == nil) {
                    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
                    if (attributes) {
                        attachment.entityTag = [AppDelegate etagFromAttributes:attributes];
                    } else {
                        attachment.entityTag = nil;
                    }
                }
                if (attachment.fileModificationDate == nil) {
                    attachment.fileModificationDate = [AppDelegate getModificationDateForPath:fullPath];
                }
                
                if (attachment.message != nil && attachment.available) {
                    /*
                    if ([AppDelegate isUserReadWriteFile:fullPath]) {
                        //[AppDelegate setPosixPermissionsReadOnlyForPath:fullPath];
                        [AppDelegate setPosixPermissionsReadWriteForPath:fullPath];
                    }
                     */
                } else {
                    /*
                    if (![AppDelegate isUserReadWriteFile:fullPath]) {
                        [AppDelegate setPosixPermissionsReadWriteForPath:fullPath];
                    }
                     */
                    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
                    if (attributes) {
                        NSString * entityTag= [AppDelegate etagFromAttributes:attributes];
                        if (![entityTag isEqualToString:attachment.entityTag]) {
                            NSLog(@"Reinitializing changed attachment %@", attachment.humanReadableFileName);
                            // attachment file changed since last seen
                            attachment.previewImageData = nil;
                            attachment.previewImage = nil;
                            @autoreleasepool {
                                [attachment reinitializeInContext:context whenReady:^(Attachment * attachment, NSError * error) {
                                    NSLog(@"Reinitialized changed attachment %@, error = %@", attachment.humanReadableFileName,error);
                                    [AppDelegate.instance saveContext:context];
                                }];
                            }
                        }
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
                    NSLog(@"adding broken attachment for deletion: %@", attachment.contentURL);
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
                NSString * was = attachment.duplicate;
                attachment.duplicate = @"DUPLICATE";
                // we remember duplicates in the dictionary
                NSLog(@"marked duplicate attachment for file: %@ (was %@) %@ %@ %@", [attachmentURL lastPathComponent], was, fileDuplicate?@"fileDuplicate":@"", urlDuplicate?@"urlDuplicate":@"", macDuplicate?@"macDuplicate":@"");
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
        //@autoreleasepool {
            [self adoptOrphanedFile:file inDirectory:inDirectory];
        //}
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
                                                                               [AppDelegate.instance saveDatabase];
                                                                           }];
    }

}
/*
+ (void) adoptOrphanedFilesAsync:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory {
    AppDelegate *delegate = [AppDelegate instance];
    
    [delegate performWithLockingId:@"adoptOrphanedFiles" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        
        
        // fetch
        NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:entity];
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"orderNumber" ascending:YES];
        NSArray *sortDescriptors = @[sortDescriptor];
        
        [fetchRequest setSortDescriptors:sortDescriptors];
        
        if (DEBUG_MIGRATION) NSLog(@"Executing fetch request for all attachments");
        NSDate * start = [NSDate new];
        NSAsynchronousFetchRequest *asyncFetch = [[NSAsynchronousFetchRequest alloc]
                                                  initWithFetchRequest:fetchRequest
                                                  completionBlock:^(NSAsynchronousFetchResult *result) {
                                                      
                                                      if (result.finalResult == nil) {
                                                          NSLog(@"result not final");
                                                          return;
                                                      } else {
                                                          NSLog(@"result is final");
                                                      }

                                                      NSArray *attachments = result.finalResult;
                                                      NSDate * stop = [NSDate new];
                                                      if (DEBUG_MIGRATION) NSLog(@"Done fetch request for all attachments took %0.3f secs",[stop timeIntervalSinceDate:start]);
                                                      
                                                      [self adoptOrphanedFiles:newFiles changedFiles:changedFiles deletedFiles:deletedFiles withRemovingAttachmentsNotInFiles:allFiles inDirectory:inDirectory withAttachments:attachments inContext:context];
                                                  }];
        
         NSAsynchronousFetchResult *result = (NSAsynchronousFetchResult *)[context
                                                                          executeRequest:asyncFetch
                                                                          error:nil];
    }];
    
}
*/

+ (void) adoptOrphanedFiles:(NSArray*)newFiles changedFiles:(NSArray*)changedFiles deletedFiles:(NSArray*)deletedFiles withRemovingAttachmentsNotInFiles:(NSArray*)allFiles inDirectory:(NSURL*)inDirectory {
    AppDelegate *delegate = [AppDelegate instance];
    
    [delegate performWithLockingId:@"adoptOrphanedFiles" inNewBackgroundContext:^(NSManagedObjectContext *context) {
        
        // fetch
        NSError * myError = nil;
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:[Attachment entityName] inManagedObjectContext:context];
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        [fetchRequest setEntity:entity];
        //NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"orderNumber" ascending:YES];
        //NSArray *sortDescriptors = @[sortDescriptor];
        
        //[fetchRequest setSortDescriptors:sortDescriptors];
        
        NSMutableArray * attachments = [NSMutableArray new];
        NSArray *someAttachments = nil;
        BOOL done = NO;
        
        NSDate * startCount = [NSDate new];
        NSUInteger totalCount = [context countForFetchRequest:fetchRequest error:&myError];
        NSDate * stopCount = [NSDate new];
        if (DEBUG_TIMING) NSLog(@"Counting all %lu attachments took %0.3f secs",(unsigned long)totalCount, [stopCount timeIntervalSinceDate:startCount]);
        fetchRequest.fetchLimit = 200;

        NSDate * loopStart = [NSDate new];
        

        do {
            if (DEBUG_QUERY) NSLog(@"Executing fetch request for %lu attachments from pos %lu", (unsigned long)fetchRequest.fetchLimit, (unsigned long)fetchRequest.fetchOffset);
            NSDate * start = [NSDate new];
            
            someAttachments = [context executeFetchRequest:fetchRequest error:&myError];
            NSDate * stop = [NSDate new];
            if (myError != nil) {
                NSLog(@"adoptOrphanedFiles: fetchrequest error = %@", myError);
                done = YES;
            }
            if (DEBUG_TIMING) NSLog(@"Done fetch request for %lu attachments from %lu took %0.3f secs",(unsigned long)someAttachments.count, (unsigned long)fetchRequest.fetchOffset, [stop timeIntervalSinceDate:start]);
            
            [attachments addObjectsFromArray:someAttachments];
            fetchRequest.fetchOffset = fetchRequest.fetchOffset + someAttachments.count;

            if (DEBUG_QUERY) NSLog(@"fetchLimit %lu got %lu",(unsigned long)fetchRequest.fetchLimit, (unsigned long)someAttachments.count);
            done = done || (fetchRequest.fetchLimit > someAttachments.count);
            if (DEBUG_QUERY) NSLog(@"done = %d",done);
            
            if (fetchRequest.fetchOffset > totalCount + fetchRequest.fetchLimit * 2) {
                NSLog(@"fetching too much slices, starting over");
                [context reset];
                attachments = [NSMutableArray new];
                fetchRequest.fetchOffset = 0;
                fetchRequest.fetchLimit = -1;
                totalCount = [context countForFetchRequest:fetchRequest error:&myError];
                fetchRequest.fetchLimit = 200;
            }

        } while (!done);
        
        NSDate * loopEnd = [NSDate new];
        if (DEBUG_TIMING) NSLog(@"Fetching all %lu attachments took %0.3f secs",(unsigned long)attachments.count, [loopEnd timeIntervalSinceDate:loopStart]);

        
        if (DEBUG_TIMING) NSLog(@"Start sorting %lu attachments",(unsigned long)attachments.count);

        NSDate * start = [NSDate new];

        // sort
        NSArray * sortedAttachments = [attachments sortedArrayUsingComparator:^NSComparisonResult(Attachment *p1, Attachment *p2){
            //return [p1.orderNumber compare:p2.orderNumber];
            NSComparisonResult result = [p1.objectID.URIRepresentation.lastPathComponent compare:p2.objectID.URIRepresentation.lastPathComponent];
            if (result == NSOrderedSame) {
                //NSLog(@"same attachment exists twice: %@ : %@", p1.objectID.URIRepresentation, p2.objectID.URIRepresentation);
            }
            return result;
        }];
        NSDate * stop = [NSDate new];
        if (DEBUG_TIMING) NSLog(@"Sorting %lu attachments took %0.3f secs",(unsigned long)sortedAttachments.count, [stop timeIntervalSinceDate:start]);
        
        // make unique
        NSString * currentId = nil;
        NSMutableArray * uniqueSortedAttachments = [NSMutableArray new];
        for (Attachment * attachment in sortedAttachments) {
            NSString * newId = attachment.objectID.URIRepresentation.lastPathComponent;
            if (![newId isEqualToString:currentId]) {
                [uniqueSortedAttachments addObject:attachment];
                currentId = newId;
            } else {
                NSLog(@"ignoring same attachment %@", newId);
            }
        }
        NSDate * stop2 = [NSDate new];
        if (DEBUG_TIMING) NSLog(@"Making %lu unique attachments took %0.3f secs",(unsigned long)uniqueSortedAttachments.count, [stop2 timeIntervalSinceDate:stop]);
        
        [self adoptOrphanedFiles:newFiles changedFiles:changedFiles deletedFiles:deletedFiles withRemovingAttachmentsNotInFiles:allFiles inDirectory:inDirectory withAttachments:uniqueSortedAttachments inContext:context];
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
