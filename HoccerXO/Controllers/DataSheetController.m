//
//  DataSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DataSheetController.h"

typedef BOOL(^DataSheetItemVisitorBlock)(DataSheetItem * item);
typedef BOOL(^DataSheetSectionVisitorBlock)(DataSheetSection * section, BOOL doneWithSection);

@interface DataSheetController ()

@property (nonatomic,strong) NSArray * currentItems;
@property (nonatomic,strong) DataSheetSection * root;
@property (nonatomic,strong) DataSheetSection * currentRoot;

@end

@implementation DataSheetController

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
        [self updateCurrentItems];
    }
    return self;
}

- (void) commonInit {
    self.root = [DataSheetSection dataSheetSectionWithIdentifier: @"root"];
    _mode = DataSheetModeView;
}

- (void) visitItems: (DataSheetSection*) root usingBlock: (DataSheetItemVisitorBlock) itemBlock sectionBlock: (DataSheetSectionVisitorBlock) sectionBlock {
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    [stack addObject: root];
    while (stack.count > 0) {
        id current = stack.lastObject;
        [stack removeLastObject];
        if ([current respondsToSelector:@selector(items)]) {
            NSNumber * mark = [marks lastObject];
            if (mark && [mark unsignedIntegerValue] == stack.count) {
                [marks removeLastObject];
                if (sectionBlock && sectionBlock(current, YES)) {
                    return;
                }
            } else {
                if (sectionBlock && sectionBlock(current, NO)) {
                    return;
                }
                [marks addObject: @(stack.count)];
                [stack addObject: current];
                for (id child in [[current items] reverseObjectEnumerator]) {
                    [stack addObject: child];
                }
            }
        } else {
            if (itemBlock && itemBlock(current)) {
                return;
            }
        }
    }
}

- (void) setInspectedObject:(id)inspectedObject {
    if (_inspectedObject) {
        [self removeObjectObservers: _inspectedObject];
    }
    _inspectedObject = inspectedObject;
    if (_inspectedObject) {
        [self addObjectObservers: _inspectedObject];
    }
    if ([self.delegate respondsToSelector:@selector(controllerDidChangeObject:)]) {
        [self.delegate controllerDidChangeObject: self];
    }
}

- (void) removeObjectObservers: (id) object {
    [self visitItems: self.root usingBlock:^BOOL(DataSheetItem * item) {
        if (! [@"" isEqualToString: item.valuePath]) {
            [object removeObserver: self forKeyPath: item.valuePath];
        }
        return NO;
    } sectionBlock: nil];
}

- (void) addObjectObservers: (id) object {
    [self visitItems: self.root usingBlock:^BOOL(DataSheetItem * item) {
        if (item.valuePath && ! [item.valuePath isEqualToString: @""]) {
            [object addObserver: self forKeyPath: item.valuePath options:NSKeyValueObservingOptionNew context: NULL];
        }
        return NO;
    } sectionBlock: nil];
}

- (id) valueForItem: (DataSheetItem*) item {
    return [_inspectedObject valueForKeyPath: item.valuePath];
}

- (DataSheetItem*) findItem: (id) root withKeyPath: (NSString*) keyPath equalTo: (id) value {
    __block DataSheetItem * result = nil;
    [self visitItems: root usingBlock:^BOOL(DataSheetItem * item) {
        id v = [item valueForKeyPath: keyPath];
        if ([value isEqual: v] ||
            ([value respondsToSelector:@selector(isEqualToString:)] && [value isEqualToString: v]) ||
            ([value respondsToSelector:@selector(isEqualToData:)] && [value isEqualToData: v]))
        {
            result = item;
            return YES;
        }
        return NO;
    } sectionBlock: nil];
    return result;
}

- (DataSheetSection*) findSection: (id) root withIdentifier: (NSString*) identifier {
    __block DataSheetSection * result = nil;
    [self visitItems: root usingBlock: nil sectionBlock:^BOOL(DataSheetSection *section, BOOL doneWithSection) {
        if ([section.identifier isEqualToString: identifier]) {
            result = section;
            return YES;
        }
        return NO;
    }];
    return result;
}

- (NSIndexPath*) indexPathForItem: (id) aItem {
    __block NSMutableArray * path = [NSMutableArray array];
    [self visitItems: self.currentRoot usingBlock:^BOOL(DataSheetItem *item) {
        if ([item isEqual: aItem]) {
            return YES;
        }
        NSNumber * index = [path lastObject];
        [path removeLastObject];
        index = @([index unsignedIntegerValue] + 1);
        [path addObject: index];
        return NO;
    } sectionBlock:^BOOL(DataSheetSection *section, BOOL doneWithSection) {
        if (doneWithSection) {
            [path removeLastObject];
            if ([path lastObject]) {
                NSNumber * index = [path lastObject];
                [path removeLastObject];
                index = @([index unsignedIntegerValue] + 1);
                [path addObject: index];
            }
        } else {
            if ([section isEqual: aItem]) {
                return YES;
            }
            [path addObject: @(0)];
        }
        return NO;
    }];
    NSMutableData * indexData = [NSMutableData dataWithLength: sizeof(NSUInteger) * path.count];
    NSUInteger * indices = indexData.mutableBytes;
    for (NSNumber * index in path) {
        *indices++ = [index unsignedIntegerValue];
    }
    NSIndexPath * p = [NSIndexPath indexPathWithIndexes: indexData.bytes length: path.count];
    return p;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: _inspectedObject]) {

        DataSheetItem * item = [self findItem: self.currentRoot withKeyPath: @"valuePath" equalTo: keyPath];
        NSIndexPath * indexPath = [self indexPathForItem: item];
        if (item && indexPath) {
            [self.delegate controllerWillChangeContent: self];
            [self.delegate controller: self didChangeObject: indexPath forChangeType: DataSheetChangeUpdate newIndexPath: nil];
            [self.delegate controllerDidChangeContent: self];
        }
    }

}

- (DataSheetItem*) itemWithIdentifier: (NSString*) identifier cellIdentifier: (NSString*) cellIdentifier {
    DataSheetItem * item = [DataSheetItem dataSheetItem];
    item.identifier = identifier;
    item.title = NSLocalizedString(identifier, nil);
    item.cellIdentifier = cellIdentifier;
    item.visibilityMask = DataSheetModeEdit | DataSheetModeView;
    item.enabledMask = DataSheetModeView | DataSheetModeEdit;
    item.delegate = self;
    return item;
}

- (DataSheetItem*) itemForIndexPath: (NSIndexPath*) indexPath {
    id current = self.currentRoot;
    for (unsigned i = 0; i < indexPath.length; ++i) {
        NSUInteger index = [indexPath indexAtPosition: i];
        current = [current items][index];
    }
    return current;
}

- (void) editModeChanged:(id)sender {
    _mode = _mode == DataSheetModeEdit ? DataSheetModeView : DataSheetModeEdit;
    [self updateCurrentItems];
}

- (BOOL) isEditing {
    return self.mode == DataSheetModeEdit;
}

- (void) updateCurrentItems {
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    NSMutableArray * insertedItems = [NSMutableArray array];
    NSMutableArray * insertedSections = [NSMutableArray array];
    DataSheetSection * oldRoot = self.currentRoot;
    [self visitItems: self.root usingBlock:^BOOL(DataSheetItem *item) {
        if (item.visibilityMask & self.mode) {
            [stack addObject: item];
            if (oldRoot && ! [self findItem: oldRoot withKeyPath: @"identifier" equalTo: item.identifier]) {
                [insertedItems addObject: item];
            }
        }
        return NO;
    } sectionBlock:^BOOL(DataSheetSection *section, BOOL doneWithSection) {
        if (doneWithSection) {
            NSNumber * mark = [marks lastObject];
            NSUInteger first = [mark unsignedIntegerValue] + 1;
            [marks removeLastObject];
            NSArray * items = [stack subarrayWithRange: NSMakeRange(first, stack.count - first)];
            while (stack.count > first) { [stack removeLastObject]; }
            DataSheetSection * newSection = [stack lastObject];
            if (items.count == 0) {
                [stack removeLastObject];
            } else {
                newSection.items = items;
            }
        } else {
            DataSheetSection * newSection = [DataSheetSection dataSheetSectionWithIdentifier: section.identifier]; // TODO: proper copy
            if (oldRoot && ! [self findSection: oldRoot withIdentifier: section.identifier]) {
                [insertedSections addObject: newSection];
            }
            [marks addObject: @(stack.count)];
            [stack addObject: newSection];
        }
        return NO;
    }];

    DataSheetSection * newRoot = [stack firstObject];

    NSMutableArray * deletedItemsIndexPaths = [NSMutableArray array];
    NSMutableArray * deletedSectionsIndexPaths = [NSMutableArray array];
    if (oldRoot) {
        [self visitItems: oldRoot usingBlock:^BOOL(DataSheetItem *item) {
            if ( ! [self findItem: newRoot withKeyPath: @"identifier" equalTo: item.identifier]) {
                NSIndexPath * indexPath = [self indexPathForItem: item];
                NSIndexPath * sectionPath = [indexPath indexPathByRemovingLastIndex];
                __block BOOL sectionIsGone = NO;
                [deletedSectionsIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * section, NSUInteger idx, BOOL *stop) {
                    if ([section compare: sectionPath] == NSOrderedSame) {
                        sectionIsGone = YES;
                        *stop = YES;
                    }
                }];
                if ( ! sectionIsGone) {
                    [deletedItemsIndexPaths addObject: indexPath];
                }
            }
            return NO;
        } sectionBlock:^BOOL(DataSheetSection *section, BOOL doneWithSection) {
            if ( ! doneWithSection) {

                if ( ! [self findSection: newRoot withIdentifier: section.identifier]) {
                    [deletedSectionsIndexPaths addObject: [self indexPathForItem: section]];
                }
            }
            return NO;
        }];
    }


    self.currentRoot = newRoot;

    [self.delegate controllerWillChangeContent: self];

    for (NSIndexPath * indexPath in deletedSectionsIndexPaths) {
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DataSheetChangeDelete];
    }

    for (DataSheetSection * section in insertedSections) {
        NSIndexPath * indexPath = [self indexPathForItem: section];
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DataSheetChangeInsert];
    }

    for (DataSheetItem * item in insertedItems) {
        NSIndexPath * indexPath = [self indexPathForItem: item];
        [self.delegate controller: self didChangeObject: nil forChangeType: DataSheetChangeInsert newIndexPath: indexPath];
    }
    
    for (NSIndexPath * indexPath in deletedItemsIndexPaths) {
        [self.delegate controller: self didChangeObject: indexPath forChangeType: DataSheetChangeDelete newIndexPath: nil];
    }
    [self.delegate controllerDidChangeContent: self];
}

- (void) setItems:(NSArray *)items {
    self.root.items = items;
}

- (NSArray*) items {
    return self.root.items;
}

- (NSArray*) currentItems {
    return self.currentRoot.items;
}

@end


@implementation DataSheetItem

+ (id) dataSheetItem {
    return [[DataSheetItem alloc] init];
}

@end

@implementation DataSheetSection

+ (id) dataSheetSection {
    return [[DataSheetSection alloc] init];
}

+ (id) dataSheetSectionWithIdentifier:(NSString *)identifier {
    DataSheetSection * section = [[DataSheetSection alloc] init];
    section.identifier = identifier;
    return section;
}


@end