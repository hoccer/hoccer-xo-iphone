//
//  HXOArrayPlaylist.m
//  HoccerXO
//
//  Created by Guido Lorenz on 10.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOArrayPlaylist.h"

#import "AppDelegate.h"
#import "Attachment.h"
#import "NSArray+RemoveObject.h"

@interface HXOArrayPlaylist ()

@property (nonatomic, strong) NSArray *array;

@end

@implementation HXOArrayPlaylist

#pragma mark - Lifecycle

- (id) initWithArray:(NSArray *)array {
    self = [super init];
    
    if (self) {
        self.array = array;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:[[AppDelegate instance] mainObjectContext]];
    }
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:[[AppDelegate instance] mainObjectContext]];
}

#pragma mark - Playlist Protocol

- (NSUInteger) count {
    return [self.array count];
}

- (Attachment *) attachmentAtIndex:(NSUInteger)index {
    return [self.array objectAtIndex:index];
}

#pragma mark - Notification handling

- (void) objectsDidChange: (NSNotification *) notification {
    NSArray *deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
    
    for (id object in deletedObjects) {
        if ([object isKindOfClass:[Attachment class]]) {
            Attachment *attachment = (Attachment *)object;
            NSUInteger index = [self.array indexOfObject:attachment];
            
            if (index != NSNotFound) {
                self.array = [self.array arrayByRemovingObject:attachment];
                [self.delegate playlist:self didRemoveAttachmentAtIndex:index];
            }
        }
    }
}

@end
