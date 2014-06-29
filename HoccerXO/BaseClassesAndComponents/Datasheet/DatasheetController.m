//
//  DatasheetController.m
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetController.h"
#import "AppDelegate.h"

#define DEBUG_VALUE_UPDATING NO

typedef BOOL(^DatasheetItemVisitorBlock)(DatasheetItem * item);
typedef BOOL(^DatasheetSectionVisitorBlock)(DatasheetSection * section, BOOL doneWithSection);

@interface DatasheetController ()

@property (nonatomic,strong) DatasheetSection * currentItems;
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
    _isCancelable = YES;
}

- (void) dealloc {
    if (_inspectedObject) {
        [self removeObjectObservers];
    }
}

- (NSArray*) buildSections {
    return @[];
}

- (void) visitItems: (DatasheetSection*) root usingBlock: (DatasheetItemVisitorBlock) itemBlock sectionBlock: (DatasheetSectionVisitorBlock) sectionBlock {
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    if (! root) {
        return;
    }
    [stack addObject: root];
    while (stack.count > 0) {
        id current = stack.lastObject;
        [stack removeLastObject];
        if ([current respondsToSelector:@selector(objectAtIndexedSubscript:)]) {
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
                for (int i = [current count] - 1; i >= 0; --i) {
                    [stack addObject: current[i]];
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
    if (inspectedObject != _inspectedObject) {
        [self inspectedObjectWillChange];
        if (_inspectedObject) {
            [self removeObjectObservers];
        }
        [AppDelegate.instance endInspecting:_inspectedObject withInspector:self];
        _inspectedObject = inspectedObject;
        [AppDelegate.instance beginInspecting:_inspectedObject withInspector:self];
        if (_inspectedObject) {
            [self addObjectObservers];
        }
        [self inspectedObjectDidChange];
    }
}

- (void) removeObjectObservers {
    NSArray * paths = [self collectAllObservedPaths];
    for (NSString * path in paths) {
        [_inspectedObject removeObserver: self forKeyPath: path];
    }
}

- (void) addObjectObservers {
    NSArray * paths = [self collectAllObservedPaths];
    for (NSString * path in paths) {
        [_inspectedObject addObserver: self forKeyPath: path options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context: NULL];
    }
}

- (NSArray*) collectAllObservedPaths {
    NSMutableSet * paths = [NSMutableSet set];
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if (DEBUG_VALUE_UPDATING) NSLog(@"collectAllObservedPaths: visiting =%@", item.valuePath);
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
    if (DEBUG_VALUE_UPDATING) NSLog(@"collectAllObservedPaths: paths =%@", paths);
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
            if ([section.identifier isEqualToString: [aItem identifier]]) {
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
    if (DEBUG_VALUE_UPDATING) NSLog(@"observeValueForKeyPath: %@, change=%@", keyPath, change);
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

        // We unfortunately need that here when visibility of items changes due to relationship updates (e.g. blockItem is not shown when contact is invited)
        [self updateCurrentItems];
    }
}

- (void) didChangeValueForItem: (DatasheetItem*) item {
}

- (void) updateItem: (DatasheetItem*) item {
    [self.delegate controllerWillChangeContent: self];
    [self.delegate controller: self didChangeObject: [self indexPathForItem: item] forChangeType: DatasheetChangeUpdate newIndexPath: nil];
    [self didChangeValueForItem: item];
    [self.delegate controllerDidChangeContent: self];
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

- (id) itemAtIndexPath: (NSIndexPath*) indexPath {
    id current = self.currentRoot;
    for (unsigned i = 0; i < indexPath.length; ++i) {
        NSUInteger index = [indexPath indexAtPosition: i];
        current = current[index];
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
    [self backgroundImageChanged];
}

- (void) cancelEditing:(id)sender {
    [self clearCurrentValues];
    _mode = DatasheetModeView;
    [self updateCurrentItems];
}

- (void) clearCurrentValues {
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        [item clearCurrentValue];
        return NO;
    } sectionBlock: nil];
}

- (void) updateInspectedObject {
    [self willUpdateInspectedObject];
    
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if (item.valuePath) {
            if (item.currentValueIsModified) {
                [self.inspectedObject setValue: item.currentValue forKeyPath: item.valuePath];
            }
        }
        return NO;
    } sectionBlock: nil];

    [self didUpdateInspectedObject];
}

- (void) didUpdateInspectedObject {
}

- (void) willUpdateInspectedObject {
}

- (BOOL) isEditing {
    return self.mode == DatasheetModeEdit;
}

- (void) updateCurrentItems {
    if (DEBUG_VALUE_UPDATING) NSLog(@"DatasheetController:updateCurrentItems");
    NSDate * startUpdate = [NSDate new];
    NSMutableArray * stack = [NSMutableArray array];
    NSMutableArray * marks = [NSMutableArray array];
    DatasheetSection * oldRoot = self.currentRoot;
    if (DEBUG_VALUE_UPDATING) NSLog(@"---- Visiting Part 1:");
    [self visitItems: self.root usingBlock:^BOOL(DatasheetItem *item) {
        if ([self isItemVisible: item]) {
            [stack addObject: item];
            if (DEBUG_VALUE_UPDATING) NSLog(@"adding item: type: %@ id: %@ value: %@", item.class, item.identifier, item.currentValue);
        }
        return NO;
    } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
        if (doneWithSection) {
            if (DEBUG_VALUE_UPDATING) NSLog(@"doneWithSection: type: %@ id: %@", section.class, section.identifier);
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
            if (DEBUG_VALUE_UPDATING) NSLog(@"copySection: type: %@ id: %@", section.class, section.identifier);
            DatasheetSection * newSection = [section copy];
            newSection.dataSource = nil; // take content authority
            [marks addObject: @(stack.count)];
            [stack addObject: newSection];
        }
        return NO;
    }];
    
    if (DEBUG_VALUE_UPDATING) {
        NSLog(@"---- stack:");
        for (DatasheetItem * item in stack) {
            if ([item isKindOfClass:[DatasheetItem class]]) {
                NSLog(@"item: type: %@ id: %@ value: %@", item.class, item.identifier, item.currentValue);
            } else {
                NSLog(@"section: type: %@ id: %@", item.class, item.identifier);
            }
        }
    }

    DatasheetSection * newRoot = [stack firstObject];

    NSMutableArray * insertedItems = [NSMutableArray array];
    NSMutableArray * insertedSections = [NSMutableArray array];
    NSMutableArray * survivingItems = [NSMutableArray array];
    if (DEBUG_VALUE_UPDATING) NSLog(@"---- Visiting Part 2:");
    if (oldRoot) {
        [self visitItems: newRoot usingBlock:^BOOL(DatasheetItem *item) {
            if([self findItem: oldRoot withKeyPath: @"identifier" equalTo: item.identifier]) {
                if (DEBUG_VALUE_UPDATING) NSLog(@"surviving item type: %@ id: %@ value: %@", item.class, item.identifier, item.currentValue);
                [survivingItems addObject: item];
            } else {
                if (DEBUG_VALUE_UPDATING) NSLog(@"inserted item type: %@ id: %@ value: %@", item.class, item.identifier, item.currentValue);
                [insertedItems addObject: item];
            }
            return NO;
        } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
            if (! doneWithSection && ! [self findSection: oldRoot withIdentifier: section.identifier]) {
                if (DEBUG_VALUE_UPDATING) NSLog(@"insertedSection: type: %@ id: %@", section.class, section.identifier);
                [insertedSections addObject: section];
            }
            return NO;
        }];
        
    }

    if (DEBUG_VALUE_UPDATING) NSLog(@"---- Visiting Part 3:");

    NSMutableArray * deletedItemsIndexPaths = [NSMutableArray array];
    NSMutableArray * deletedSectionsIndexPaths = [NSMutableArray array];
    if (oldRoot) {
        [self visitItems: oldRoot usingBlock:^BOOL(DatasheetItem *item) {
            if (DEBUG_VALUE_UPDATING) NSLog(@"visit item type: %@ id: %@ value: %@", item.class, item.identifier, item.currentValue);
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
                    if (DEBUG_VALUE_UPDATING) NSLog(@"deletedItemsIndexPaths: adding path %@", indexPath);
                    [deletedItemsIndexPaths addObject: indexPath];
                }
            }
            return NO;
        } sectionBlock:^BOOL(DatasheetSection *section, BOOL doneWithSection) {
            if ( ! doneWithSection) {

                if ( ! [self findSection: newRoot withIdentifier: section.identifier]) {
                    if (DEBUG_VALUE_UPDATING) NSLog(@"deletedSectionsIndexPaths: adding path %@", [self indexPathForItem: section]);
                    [deletedSectionsIndexPaths addObject: [self indexPathForItem: section]];
                }
            }
            return NO;
        }];
    }

    self.currentRoot = newRoot;

    [self.delegate controllerWillChangeContent: self];

    if (DEBUG_VALUE_UPDATING) NSLog(@"deletedSections=%d", deletedSectionsIndexPaths.count);
    for (NSIndexPath * indexPath in deletedSectionsIndexPaths) {
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DatasheetChangeDelete];
    }

    if (DEBUG_VALUE_UPDATING) NSLog(@"insertedSections=%d", insertedSections.count);
    for (DatasheetSection * section in insertedSections) {
        NSIndexPath * indexPath = [self indexPathForItem: section];
        if (DEBUG_VALUE_UPDATING) NSLog(@"insertedSection path=%@", indexPath);
        [self.delegate controller: self didChangeSection: indexPath forChangeType: DatasheetChangeInsert];
    }

    if (DEBUG_VALUE_UPDATING) NSLog(@"insertedItems=%d", insertedItems.count);
    for (DatasheetItem * item in insertedItems) {
        NSIndexPath * indexPath = [self indexPathForItem: item];
        if (DEBUG_VALUE_UPDATING) NSLog(@"insertedItem path=%@", indexPath);
        [self.delegate controller: self didChangeObject: nil forChangeType: DatasheetChangeInsert newIndexPath: indexPath];
    }
    
    if (DEBUG_VALUE_UPDATING) NSLog(@"deletedItemsIndexPaths=%d", deletedItemsIndexPaths.count);
    for (NSIndexPath * indexPath in deletedItemsIndexPaths) {
        if (DEBUG_VALUE_UPDATING) NSLog(@"deletedItem path=%@", indexPath);
        [self.delegate controller: self didChangeObject: indexPath forChangeType: DatasheetChangeDelete newIndexPath: nil];
    }

    if (DEBUG_VALUE_UPDATING) NSLog(@"survivingItems=%d", survivingItems.count);
    for (DatasheetItem * item in survivingItems) {
        NSIndexPath * indexPath = [self indexPathForItem: item];
        if (DEBUG_VALUE_UPDATING) NSLog(@"survivingItem path=%@", indexPath);
       [self.delegate controller: self didChangeObject: indexPath forChangeType: DatasheetChangeUpdate newIndexPath: nil];
    }
    [self.delegate controllerDidChangeContent: self];
    NSDate * stopUpdate = [NSDate new];
    if (DEBUG_VALUE_UPDATING) NSLog(@"update took %1.3f secs.", [stopUpdate timeIntervalSinceDate:startUpdate]);
    if (DEBUG_VALUE_UPDATING) NSLog(@"%@", [NSThread callStackSymbols]);
}

- (void) setItems:(NSArray *)items {
    self.root.items = items;
}

- (DatasheetSection*) items {
    return self.root;
}

- (DatasheetSection*) currentItems {
    return self.currentRoot;
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

- (void) setDelegate:(UIViewController<DatasheetControllerDelegate>*)delegate {
//    [self inspectedObjectWillChange];
    _delegate = delegate;
//    [self inspectedObjectDidChange];
//    [self backgroundImageChanged];
//    [self titleChanged];
}

- (void) inspectedObjectWillChange {
}

- (void) inspectedObjectDidChange {
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

- (void) titleChanged {
    if ([self.delegate respondsToSelector: @selector(controllerDidChangeTitle:)]) {
        [self.delegate controllerDidChangeTitle: self];
    }
}

- (UIImage*) updateBackgroundImage {
    return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue withItem: (DatasheetItem*) item sender:(id)sender {
}

- (void) registerCellClasses: (DatasheetViewController*) tableView {
}

- (void) configureCell: (id) cell withItem: (DatasheetItem*) item atIndexPath: (NSIndexPath*) indexPath {
}

- (void) editInsertItem:(DatasheetItem *)item {
}

- (void) editRemoveItem:(DatasheetItem *)item {
}

@end

//==============================================================================


@implementation DatasheetItem

@synthesize currentValue = _currentValue;

- (BOOL) isVisible {
    return [self.delegate isItemVisible: self];
}

- (BOOL) isEnabled {
    return [self.delegate isItemEnabled: self];
}

- (id) currentValue {
    if (_currentValueIsModified) {
        return _currentValue;
    }
    return [self.delegate valueForItem: self];
}

- (void) setCurrentValue:(id)currentValue {
    _currentValue = currentValue;
    _currentValueIsModified = YES;
}

- (void) clearCurrentValue {
    _currentValueIsModified = NO;
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

- (BOOL) isDeletable {
    if ([self.delegate respondsToSelector: @selector(isItemDeletable:)]) {
        return [self.delegate isItemDeletable: self];
    }
    return NO;
}

- (NSString*) deleteButtonTitle {
    if (_deleteButtonTitle) {
        return _deleteButtonTitle;
    }
    if ([self.delegate respondsToSelector: @selector(deleteButtonTitleForItem:)]) {
        return [self.delegate deleteButtonTitleForItem: self];
    }
    return nil;
}
@end


//==============================================================================

@implementation DatasheetSection

- (id) init {
    self = [super init];
    if (self) {
    }
    return self;
}

+ (id) dataSheetSection {
    return [[DatasheetSection alloc] init];
}

+ (id) datasheetSectionWithIdentifier:(NSString *)identifier {
    DatasheetSection * section = [[DatasheetSection alloc] init];
    section.identifier = identifier;
    return section;
}

- (NSString*) footerViewIdentifier {
    if (! _footerViewIdentifier && self.footerText) {
        return @"DatasheetHeaderFooterTextView";
    }
    return _footerViewIdentifier;
}

- (NSString*) headerViewIdentifier {
    if (! _headerViewIdentifier && self.title) {
        return @"DatasheetHeaderFooterTextView";
    }
    return _headerViewIdentifier;
}

-(id)copyWithZone:(NSZone *)zone {
    // We'll ignore the zone for now
    DatasheetSection * copy = [[DatasheetSection alloc] init];
    copy.identifier = _identifier;
    copy.footerViewIdentifier = _footerViewIdentifier;
    copy.headerViewIdentifier = _headerViewIdentifier;
    copy.title = _title;
    copy.titleTextAlignment = _titleTextAlignment;
    copy.footerText = _footerText;
    copy.delegate = _delegate;
    copy.dataSource = _dataSource;
    copy.items = _items;
    return copy;
}

- (void) setItems: (NSArray*) items {
    _items = items;
}

- (NSUInteger) count {
    if ([self.dataSource respondsToSelector: @selector(numberOfItemsInSection:)]) {
        return [self.dataSource numberOfItemsInSection: self];
    }
    return _items.count;
}

- (id) objectAtIndexedSubscript: (NSUInteger) index {
    if ([self.dataSource respondsToSelector: @selector(section:itemAtIndex:)]) {
        return [self.dataSource section: self itemAtIndex: index];
    }
    return _items[index];
}

- (id) reverseObjectEnumerator {
    return _items.reverseObjectEnumerator;
}

- (NSAttributedString*) title {
    if (_title) {
        return _title;
    }
    if ([self.delegate respondsToSelector: @selector(titleForSection:)]) {
        return [self.delegate titleForSection: self];
    }
    return nil;
}
@end