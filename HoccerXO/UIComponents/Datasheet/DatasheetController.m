//
//  DatasheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetController.h"

typedef BOOL(^DatasheetItemVisitorBlock)(DatasheetItem * item);
typedef BOOL(^DatasheetSectionVisitorBlock)(DatasheetSection * section, BOOL doneWithSection);

@interface DatasheetController ()

@property (nonatomic,strong) NSArray * currentItems;
@property (nonatomic,strong) DatasheetSection * root;
@property (nonatomic,strong) DatasheetSection * currentRoot;

@end

@implementation DatasheetController

- (id) init {
    self = [super init];
    if (self) {
        [self commonInit];
        self.root = [DatasheetSection datasheetSectionWithIdentifier: @"root"];
        self.root.items = [self buildSections];
        [self updateCurrentItems];
    }
    return self;
}

- (void) commonInit {
    _mode = DatasheetModeView;
}

- (void) dealloc {
    if (_inspectedObject) {
        [self removeObjectObservers: _inspectedObject];
    }
}

- (NSArray*) buildSections {
    return @[];
}

- (void) visitItems: (DatasheetSection*) root usingBlock: (DatasheetItemVisitorBlock) itemBlock sectionBlock: (DatasheetSectionVisitorBlock) sectionBlock {
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
    [self inspectedObjectChanged];
}

- (void) removeObjectObservers: (id) object {
    NSArray * paths = [self collectAllObservedPaths];
    for (NSString * path in paths) {
        [object removeObserver: self forKeyPath: path];
    }
}

- (void) addObjectObservers: (id) object {
    NSArray * paths = [self collectAllObservedPaths];
    for (NSString * path in paths) {
        [object addObserver: self forKeyPath: path options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context: NULL];
    }
}

- (NSArray*) collectAllObservedPaths {
    NSMutableSet * paths = [NSMutableSet set];
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if ( item.valuePath && ! [paths containsObject: item.valuePath]) {
            [paths addObject: item.valuePath];
        }
        for (NSString * path in item.dependencyPaths) {
            if ( ! [paths containsObject: path]) {
                [paths addObject: path];
            }
        }
        return NO;
    } sectionBlock: nil];
    return [paths allObjects];
}

- (id) valueForItem: (DatasheetItem*) item {
    return [_inspectedObject valueForKeyPath: item.valuePath];
}

- (DatasheetItem*) findItem: (id) root withKeyPath: (NSString*) keyPath equalTo: (id) value {
    __block DatasheetItem * result = nil;
    [self visitItems: root usingBlock:^BOOL(DatasheetItem * item) {
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

- (DatasheetSection*) findSection: (id) root withIdentifier: (NSString*) identifier {
    __block DatasheetSection * result = nil;
    [self visitItems: root usingBlock: nil sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
        if ( ! doneWithSection && [section.identifier isEqualToString: identifier]) {
            result = section;
            return YES;
        }
        return NO;
    }];
    return result;
}

- (NSIndexPath*) indexPathForItem: (id) aItem {
    __block NSMutableArray * path = [NSMutableArray array];
    [self visitItems: self.currentRoot usingBlock:^BOOL(DatasheetItem *item) {
        if ([item isEqual: aItem]) {
            return YES;
        }
        NSNumber * index = [path lastObject];
        [path removeLastObject];
        index = @([index unsignedIntegerValue] + 1);
        [path addObject: index];
        return NO;
    } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
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
    if (path.count == 0) {
        return nil;
    }
    
    NSMutableData * indexData = [NSMutableData dataWithLength: sizeof(NSUInteger) * path.count];
    NSUInteger * indices = indexData.mutableBytes;
    for (NSNumber * index in path) {
        *indices++ = [index unsignedIntegerValue];
    }
    NSIndexPath * p = [NSIndexPath indexPathWithIndexes: indexData.bytes length: path.count];
    return p;
}

- (NSArray *) findItems: (DatasheetSection*) root interestedIn: (NSString*) keyPath {
    __block NSMutableArray * result = [NSMutableArray array];
    [self visitItems: root usingBlock:^BOOL(DatasheetItem * item) {
        if ([item.valuePath isEqualToString: keyPath] || [item.dependencyPaths containsObject: keyPath]) {
            [result addObject: item];
        }
        return NO;
    } sectionBlock: nil];
    return result;

}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: _inspectedObject]) {
        NSArray * items = [self findItems: self.root interestedIn: keyPath];
        [self.delegate controllerWillChangeContent: self];
        for (DatasheetItem * item in items) {
            if ([self indexPathForItem: item]) {
                [self.delegate controller: self didChangeObject: [self indexPathForItem: item] forChangeType: DatasheetChangeUpdate newIndexPath: nil];
            }
            [self didChangeValueForItem: item];
        }
        [self.delegate controllerDidChangeContent: self];
    }
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
}

- (DatasheetItem*) itemWithIdentifier: (NSString*) identifier cellIdentifier: (NSString*) cellIdentifier {
    DatasheetItem * item = [DatasheetItem datasheetItem];
    item.identifier = identifier;
    item.cellIdentifier = cellIdentifier;
    item.visibilityMask = DatasheetModeView | DatasheetModeEdit;
    item.enabledMask = DatasheetModeView | DatasheetModeEdit;
    item.delegate = self;
    return item;
}

- (id) itemForIndexPath: (NSIndexPath*) indexPath {
    id current = self.currentRoot;
    for (unsigned i = 0; i < indexPath.length; ++i) {
        NSUInteger index = [indexPath indexAtPosition: i];
        current = [current items][index];
    }
    return current;
}

- (void) editModeChanged:(id)sender {
    if (_mode == DatasheetModeEdit) {
        [self updateInspectedObject];
        [self clearCurrentValues];
    }
    _mode = _mode == DatasheetModeEdit ? DatasheetModeView : DatasheetModeEdit;
    [self updateCurrentItems];
}

- (void) cancelEditing:(id)sender {
    [self clearCurrentValues];
    _mode = DatasheetModeView;
    [self updateCurrentItems];
}

- (void) clearCurrentValues {
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        item.currentValue = nil;
        return NO;
    } sectionBlock: nil];
}

- (void) updateInspectedObject {
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if (item.valuePath) {
            id objectValue = [self.inspectedObject valueForKeyPath: item.valuePath];
            id ourValue = item.currentValue;
            if (([objectValue respondsToSelector: @selector(isEqualToString:)] && ! [objectValue isEqualToString: ourValue]) ||
                ! [objectValue isEqual: ourValue])
            {
                [self.inspectedObject setValue: ourValue forKeyPath: item.valuePath];
            }
        }
        return NO;
    } sectionBlock: nil];

    [self didUpdateInspectedObject];
}

- (void) didUpdateInspectedObject {
}

- (BOOL) isEditing {
    return self.mode == DatasheetModeEdit;
}

- (void) updateCurrentItems {
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    DatasheetSection * oldRoot = self.currentRoot;
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if ([self isItemVisible: item]) {
            [stack addObject: item];
        }
        return NO;
    } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
        if (doneWithSection) {
            NSNumber * mark = [marks lastObject];
            NSUInteger first = [mark unsignedIntegerValue] + 1;
            [marks removeLastObject];
            NSArray * items = [stack subarrayWithRange: NSMakeRange(first, stack.count - first)];
            while (stack.count > first) { [stack removeLastObject]; }
            DatasheetSection * newSection = [stack lastObject];
            if (items.count == 0) {
                [stack removeLastObject];
            } else {
                newSection.items = items;
            }
        } else {
            DatasheetSection * newSection = [section copy];
            [marks addObject: @(stack.count)];
            [stack addObject: newSection];
        }
        return NO;
    }];

    DatasheetSection * newRoot = [stack firstObject];


    NSMutableArray * insertedItems = [NSMutableArray array];
    NSMutableArray * insertedSections = [NSMutableArray array];
    NSMutableArray * survivingItems = [NSMutableArray array];
    if (oldRoot) {
        [self visitItems: newRoot usingBlock:^BOOL(DatasheetItem *item) {
            if([self findItem: oldRoot withKeyPath: @"identifier" equalTo: item.identifier]) {
                [survivingItems addObject: item];
            } else {
                [insertedItems addObject: item];
            }
            return NO;
        } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
            if (! doneWithSection && ! [self findSection: oldRoot withIdentifier: section.identifier]) {
                [insertedSections addObject: section];
            }
            return NO;
        }];
        
    }


    NSMutableArray * deletedItemsIndexPaths = [NSMutableArray array];
    NSMutableArray * deletedSectionsIndexPaths = [NSMutableArray array];
    if (oldRoot) {
        [self visitItems: oldRoot usingBlock:^BOOL(DatasheetItem *item) {
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
        } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
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
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DatasheetChangeDelete];
    }

    for (DatasheetSection * section in insertedSections) {
        NSIndexPath * indexPath = [self indexPathForItem: section];
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DatasheetChangeInsert];
    }

    for (DatasheetItem * item in insertedItems) {
        NSIndexPath * indexPath = [self indexPathForItem: item];
        [self.delegate controller: self didChangeObject: nil forChangeType: DatasheetChangeInsert newIndexPath: indexPath];
    }
    
    for (NSIndexPath * indexPath in deletedItemsIndexPaths) {
        [self.delegate controller: self didChangeObject: indexPath forChangeType: DatasheetChangeDelete newIndexPath: nil];
    }

    for (DatasheetItem * item in survivingItems) {
        NSIndexPath * indexPath = [self indexPathForItem: item];
        [self.delegate controller: self didChangeObject: indexPath forChangeType: DatasheetChangeUpdate newIndexPath: nil];
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

- (BOOL) isItemVisible:(DatasheetItem *)item {
    return (item.visibilityMask & self.mode) != 0;
}

- (BOOL) isItemEnabled:(DatasheetItem *)item {
    return (item.enabledMask & self.mode) != 0;
}

- (UIView*) tableHeaderView {
    return nil;
}

- (BOOL) allItemsValid {
    __block BOOL allValid = YES;
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if ( ! [item isValid]) {
            allValid = NO;
            return YES;
        }
        return NO;
    } sectionBlock: nil];
    return allValid;
}

- (void) setDelegate:(id<DatasheetControllerDelegate>)delegate {
    _delegate = delegate;
    [self backgroundImageChanged];
    [self inspectedObjectChanged];
}

- (void) inspectedObjectChanged {
    [self updateCurrentItems];
    if ([self.delegate respondsToSelector:@selector(controllerDidChangeObject:)]) {
        [self.delegate controllerDidChangeObject: self];
    }
}

- (void) backgroundImageChanged {
    if ([self.delegate respondsToSelector: @selector(controller:didChangeBackgroundImage:)]) {
        [self.delegate controller: self didChangeBackgroundImage: [self updateBackgroundImage]];
    }
}

- (UIImage*) updateBackgroundImage {
    return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue withItem: (DatasheetItem*) item sender:(id)sender {
}

@end


@implementation DatasheetItem

- (BOOL) isVisible {
    return [self.delegate isItemVisible: self];
}

- (BOOL) isEnabled {
    return [self.delegate isItemEnabled: self];
}

- (id) currentValue {
    if (_currentValue) {
        return _currentValue;
    }
    return [self.delegate valueForItem: self];
}

+ (id) datasheetItem {
    return [[DatasheetItem alloc] init];
}

- (BOOL) isValid {
    return self.validator ? self.validator(self) : YES;
}

- (NSString*) title {
    NSString * title = _title;
    if ( ! title && [self.delegate respondsToSelector: @selector(titleForItem:)]) {
        title = [self.delegate titleForItem: self];
    }
    title = title ? title : self.identifier;
    return title;
}


- (UIColor*) titleTextColor {
    UIColor * color = _titleTextColor;
    if ( ! color && [self.delegate respondsToSelector: @selector(titleTextColorForItem:)]) {
        color = [self.delegate titleTextColorForItem: self];
    }
    return color;
}

- (DatasheetAccessoryStyle) accessoryStyle {
    DatasheetAccessoryStyle style = _accessoryStyle;
    if (style == DatasheetAccessoryNone && [self.delegate respondsToSelector: @selector(accessoryStyleForItem:)]) {
        style = [self.delegate accessoryStyleForItem: self];
    }
    return style;
}

- (NSString*) valueFormatString {
    if (_valueFormatString) {
        return _valueFormatString;
    }
    if ([self.delegate respondsToSelector: @selector(valueFormatStringForItem:)]) {
        return [self.delegate valueFormatStringForItem: self];
    }
    return nil;
}

- (NSString*) valuePlaceholder {
    if (_valuePlaceholder) {
        return _valuePlaceholder;
    }
    if ([self.delegate respondsToSelector: @selector(valuePlaceholderForItem:)]) {
        return [self.delegate valuePlaceholderForItem: self];
    }
    return nil;
}


- (NSString*) segueIdentifier {
    if (_segueIdentifier) {
        return _segueIdentifier;
    }
    if ([self.delegate respondsToSelector: @selector(segueIdentifierForItem:)]) {
        return [self.delegate segueIdentifierForItem: self];
    }
    return nil;
}

- (id) target {
    if (_target) {
        return _target;
    }
    if ([self.delegate respondsToSelector: @selector(targetForItem:)]) {
        return [self.delegate targetForItem: self];
    }
    return nil;
}

- (SEL) action {
    if (_action) {
        return _action;
    }
    if ([self.delegate respondsToSelector: @selector(actionForItem:)]) {
        return [self.delegate actionForItem: self];
    }
    return nil;
}


@end

@implementation DatasheetSection

+ (id) dataSheetSection {
    return [[DatasheetSection alloc] init];
}

+ (id) datasheetSectionWithIdentifier:(NSString *)identifier {
    DatasheetSection * section = [[DatasheetSection alloc] init];
    section.identifier = identifier;
    return section;
}

- (NSString*) footerViewIdentifier {
    if (! _footerViewIdentifier && _footerText) {
        return @"DatasheetFooterTextView";
    }
    return _footerViewIdentifier;
}

-(id)copyWithZone:(NSZone *)zone {
    // We'll ignore the zone for now
    DatasheetSection * copy = [[DatasheetSection alloc] init];
    copy.identifier = _identifier;
    copy.footerViewIdentifier = _footerViewIdentifier;
    copy.headerViewIdentifier = _headerViewIdentifier;
    copy.footerText = _footerText;
    copy.items = _items;
    return copy;
}


@end