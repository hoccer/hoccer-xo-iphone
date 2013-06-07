//
//  ProfileDataSource.m
//  HoccerXO
//
//  Created by David Siegel on 05.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileDataSource.h"
#import "GroupMembership.h"
#import "Contact.h"

#define PROFILE_DATA_SOURCE_DEBUG NO


@implementation GroupMembership (ProfileViewUtils)

- (NSString*) name {
    return [NSString stringWithFormat: @"GroupMembership-%@", self.contact == nil ? @"Me" : self.contact.clientId];
}

@end

@implementation ProfileDataSource

- (id) init {
    self = [super init];
    if (self != nil) {
        _currentModel = [[NSArray alloc] init];
    }
    return self;
}

- (NSUInteger) count {
    return _currentModel.count;
}

- (id) objectAtIndexedSubscript:(NSInteger)index {
    return _currentModel[index];
}

- (id) objectAtIndexPath: (NSIndexPath*) indexPath {
    if (_currentModel.count > indexPath.section && [_currentModel[indexPath.section] count] > indexPath.row) {
        return _currentModel[indexPath.section][indexPath.row];
    }
    return nil;
}

- (NSIndexPath*) indexPathForObject: (id) object {
    for (NSUInteger i = 0; i < _currentModel.count; ++i) {
        for (NSUInteger j = 0; j < [_currentModel[i] count]; ++j) {
            if ([object isEqual: _currentModel[i][j]]) {
                return [NSIndexPath indexPathForItem:j inSection:i];
            }
        }
    }
    return nil;
}

- (NSUInteger) indexOfSection: (id) section {
    return [_currentModel indexOfObject: section];
}

- (void) updateModel:(NSArray *)newModel {
    if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource: updateModel:");
    NSArray * oldModel = _currentModel;
    newModel = [self dropEmptySections: newModel];
    NSIndexSet * removedSections = [self findItemsPresentIn: oldModel butNotIn: newModel];
    NSIndexSet * insertedSections = [self findItemsPresentIn: newModel butNotIn: oldModel];

    NSMutableDictionary * newToOldSectionIndexMap = [[NSMutableDictionary alloc] init];
    for (NSUInteger i = 0; i < newModel.count; ++i) {
        if ( ! [insertedSections containsIndex: i] && ! [removedSections containsIndex: i]) {
            id<ProfileItemInfo> newSection = newModel[i];
            NSUInteger oldIndex = [oldModel indexOfObjectPassingTest:^BOOL(id<ProfileItemInfo> oldSection, NSUInteger idx, BOOL *stop) {
                return [newSection.name isEqualToString: oldSection.name];
            }];
            newToOldSectionIndexMap[@(i)] = @(oldIndex);
        }
    }
    
    [self.delegate.tableView beginUpdates];

    if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource updateModel: removing sections %@", removedSections);
    [self.delegate.tableView deleteSections: removedSections withRowAnimation: UITableViewRowAnimationFade];
    if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource updateModel: inserting sections %@", insertedSections);
    [self.delegate.tableView insertSections: insertedSections withRowAnimation: UITableViewRowAnimationFade];

    [insertedSections enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
        ProfileSection * section = newModel[sectionIndex];
        if ( ! section.managesOwnContent) {
            for (NSUInteger i = 0; i < section.count; ++i) {
                if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource updateModel: inserting row %d (%@) in new section %d (%@)", i, [section[i] name], sectionIndex, section.name);
                NSIndexPath * indexPath = [NSIndexPath indexPathForItem: i inSection: sectionIndex];
                [self.delegate.tableView insertRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];
            }
        }
    }];


    NSMutableArray * updatees = [[NSMutableArray alloc] init];
    [newToOldSectionIndexMap enumerateKeysAndObjectsUsingBlock:^(NSNumber * newIndex, NSNumber * oldIndex, BOOL *stop) {
        [self updateOldSection: oldIndex.intValue inOldModel: oldModel toMatchNewSection: newIndex.intValue inNewModel: newModel updatees:updatees];
    }];

    _currentModel = newModel;
    [self.delegate.tableView endUpdates];
    if (updatees.count > 0) {
        [self.delegate.tableView beginUpdates];
        [updatees enumerateObjectsUsingBlock:^(NSIndexPath * indexPath, NSUInteger idx, BOOL *stop) {
            [self.delegate configureCellAtIndexPath: indexPath];
        }];
        [self.delegate.tableView endUpdates];
    }
}

- (void) updateOldSection: (int) oldSectionIndex inOldModel: (NSArray*) oldModel toMatchNewSection: (int) newSectionIndex inNewModel: (NSArray*) newModel updatees: (NSMutableArray*) updatees {
    if ([newModel[newSectionIndex] managesOwnContent]) {
        return;
    }
    ProfileSection * oldSection = oldModel[oldSectionIndex];
    ProfileSection * newSection = newModel[newSectionIndex];
    NSIndexSet * removedItems = [self findItemsPresentIn: oldSection butNotIn: newSection];
    NSIndexSet * insertedItems = [self findItemsPresentIn: newSection butNotIn: oldSection];

    [removedItems enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource updateOldSection: deleting row %d (%@) in section %d (%@)", idx, [newSection[idx] name], newSectionIndex, newSection.name);
        NSIndexPath * indexPath = [NSIndexPath indexPathForItem: idx inSection: newSectionIndex];
        [self.delegate.tableView deleteRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];
    }];

    for (NSUInteger i = 0; i < newSection.count; ++i) {
        NSIndexPath * indexPath = [NSIndexPath indexPathForItem: i inSection: newSectionIndex];
        if ([insertedItems containsIndex: i]) {
            if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource updateOldSection: inserting row %d (%@) in section %d (%@)", i, [newSection[i] name], newSectionIndex, newSection.name);
            [self.delegate.tableView insertRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];
        } else {
            [updatees addObject: indexPath];
            //[self.delegate configureCellAtIndexPath: indexPath];
        }
    }

    // TODO: handle moves?
}

- (NSIndexSet*) findItemsPresentIn: (id) a butNotIn: (id) b {
    return [a indexesOfObjectsPassingTest:^BOOL(id<ProfileItemInfo> aItem, NSUInteger idx, BOOL *stop) {
        NSUInteger indexInNewModel = [b indexOfObjectPassingTest:^BOOL(id<ProfileItemInfo> bItem, NSUInteger idx, BOOL *stop) {
            BOOL isPresent = [aItem.name isEqualToString: bItem.name];
            if (isPresent) {
                *stop = YES;
            }
            return isPresent;
        }];
        return indexInNewModel == NSNotFound;
    }];
}

- (NSArray*) dropEmptySections: (NSArray*) model {
    NSIndexSet * indices = [model indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj count] > 0;
    }];
    if (PROFILE_DATA_SOURCE_DEBUG) NSLog(@"ProfileDataSource dropEmptySections: dropped %d sections", model.count - indices.count);
    return [model objectsAtIndexes: indices];
}

@end

@implementation ProfileSection

- (id) init {
    self = [super init];
    if (self != nil) {
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id) initWithArray: (NSArray*) items {
    self = [super init];
    if (self != nil) {
        _items = [[NSMutableArray alloc] initWithArray: items];
    }
    return self;
}

- (BOOL) managesOwnContent {
    return NO;
}

- (NSUInteger) count {
    return _items.count;
}

- (id) objectAtIndexedSubscript:(NSInteger)index {
    return _items[index];
}

- (void) addObject: (id) item {
    [_items addObject: item];
}

- (NSIndexSet*) indexesOfObjectsPassingTest: (BOOL(^)(id<ProfileItemInfo> aItem, NSUInteger idx, BOOL *stop)) test {
    return [_items indexesOfObjectsPassingTest: test];
}
- (NSUInteger) indexOfObjectPassingTest: (BOOL(^)(id<ProfileItemInfo> aItem, NSUInteger idx, BOOL *stop)) test {
    return [_items indexOfObjectPassingTest: test];
}

+ (id) sectionWithName: (NSString*) name items: (id) firstItem, ... {
    id item;
    ProfileSection * section = [[ProfileSection alloc] init];
    section.name = name;
    if (firstItem != nil) {
        [section addObject: firstItem];
        va_list items;
        va_start(items, firstItem);
        while (items && (item = va_arg(items, id))) {
            [section addObject: item];
        }
        va_end(items);
    }
    return section;
}

+ (id) sectionWithName: (NSString*) name array:(NSArray *)items {
    ProfileSection * section = [[ProfileSection alloc] initWithArray: items];
    section.name = name;
    return section;
}

@end

