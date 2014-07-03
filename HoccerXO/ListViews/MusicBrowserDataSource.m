//
//  MusicBrowserDataSource.m
//  HoccerXO
//
//  Created by Guido Lorenz on 03.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "MusicBrowserDataSource.h"

#import "Contact.h"

@interface MusicBrowserDataSource ()

@property (nonatomic, strong) Contact *contact;

@end

@implementation MusicBrowserDataSource

#pragma mark - Initialization

- (id) initWithContact:(Contact *)contact {
    self = [super init];
    
    if (self) {
        self.contact = contact;
    }
    
    return self;
}

+ (NSFetchRequest *)fetchRequestWithManagedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    return [MusicBrowserDataSource fetchRequestForContact:nil managedObjectModel:managedObjectModel];
}

+ (NSFetchRequest *)fetchRequestForContact:(Contact *)contact managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
    NSDictionary *vars = @{ @"contact" : contact ? contact : [NSNull null] };
    
    NSFetchRequest *fetchRequest = [managedObjectModel fetchRequestFromTemplateWithName:@"ReceivedAudioAttachments" substitutionVariables:vars];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"message.timeReceived" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return fetchRequest;
}

- (NSFetchRequest *) fetchRequest {
    if (self.contact) {
        return [MusicBrowserDataSource fetchRequestForContact:self.contact managedObjectModel:self.managedObjectModel];
    } else {
        return [MusicBrowserDataSource fetchRequestWithManagedObjectModel:self.managedObjectModel];
    }
}

@end
