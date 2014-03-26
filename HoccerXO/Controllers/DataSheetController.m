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


@implementation DataSheetController

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    
}

- (void) visitItemsUsingBlock: (DataSheetItemVisitorBlock) itemBlock sectionBlock: (DataSheetSectionVisitorBlock) sectionBlock {
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    for (id section in [self.items reverseObjectEnumerator]) {
        [stack addObject: section];
    }
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
}

- (void) removeObjectObservers: (id) object {
    [self visitItemsUsingBlock:^BOOL(DataSheetItem * item) {
        if (item.valuePath && ! [item.valuePath isEqualToString: @""]) {
            [object removeObserver: self forKeyPath: item.valuePath];
        }
        return NO;
    } sectionBlock: nil];
}

- (void) addObjectObservers: (id) object {
    [self visitItemsUsingBlock:^BOOL(DataSheetItem * item) {
        if (item.valuePath && ! [item.valuePath isEqualToString: @""]) {
            [object addObserver: self forKeyPath: item.valuePath options:NSKeyValueObservingOptionNew context: NULL];
        }
        return NO;
    } sectionBlock: nil];
}

- (id) valueForItem: (DataSheetItem*) item {
    return [_inspectedObject valueForKeyPath: item.valuePath];
}

- (DataSheetItem*) findItemWithKeyPath: (NSString*) keyPath equalTo: (id) value {
    __block DataSheetItem * result = nil;
    [self visitItemsUsingBlock:^BOOL(DataSheetItem * item) {
        id v = [item valueForKeyPath: keyPath];
        if ([value isEqual: v] || [value isEqualToString: v] || [value isEqualToData: v]) {
            result = item;
            return YES;
        }
        return NO;
    } sectionBlock: nil];
    return result;
}

- (NSIndexPath*) indexPathForItem: (DataSheetItem*) aItem {
    __block NSMutableArray * path = [NSMutableArray arrayWithObject: @(0)];
    [self visitItemsUsingBlock:^BOOL(DataSheetItem *item) {
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
        } else {
            [path addObject: @(0)];
        }
        return NO;
    }];
    NSLog(@"==== %@",[path componentsJoinedByString:@", "]);
    NSMutableData * indexData = [NSMutableData dataWithLength:sizeof(NSUInteger) * path.count];
    NSUInteger * indices = indexData.mutableBytes;
    for (NSNumber * index in path) {
        *indices++ = [index unsignedIntegerValue];
    }
    return [NSIndexPath indexPathWithIndexes: indices length: path.count];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: _inspectedObject]) {

        DataSheetItem * item = [self findItemWithKeyPath: @"valuePath" equalTo: keyPath];
        NSIndexPath * indexPath = [self indexPathForItem: item];
        if (item && indexPath) {
            [self.delegate controllerWillChangeContent: self];
            [self.delegate controller: self didChangeObject: indexPath forChangeType: DataSheetChangeUpdate newIndexPath: nil];
            [self.delegate controllerDidChangeContent: self];
        }
    }

}

- (DataSheetItem*) itemWithTitle: (NSString*) titleKey cellIdentifier: (NSString*) cellIdentifier {
    DataSheetItem * item = [DataSheetItem dataSheetItem];
    item.title = NSLocalizedString( titleKey,  nil);
    item.cellIdentifier = cellIdentifier;
    item.delegate = self;
    return item;
}

- (DataSheetItem*) itemForIndexPath: (NSIndexPath*) indexPath {
    id current = self;
    for (unsigned i = 0; i < indexPath.length; ++i) {
        NSUInteger index = [indexPath indexAtPosition: i];
        current = [current items][index];
    }
    return current;
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


@end