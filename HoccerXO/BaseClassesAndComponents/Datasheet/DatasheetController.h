//
//  DatasheetController.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@class DatasheetController;
@class DatasheetItem;
@class DatasheetSection;
@class DatasheetViewController;

typedef enum DatasheetChangeTypes {
    DatasheetChangeInsert,
    DatasheetChangeDelete,
    DatasheetChangeMove,
    DatasheetChangeUpdate
} DatasheetChangeType;

typedef enum DatasheetModes {
    DatasheetModeNone = 0,
    DatasheetModeEdit = (1<<0),
    DatasheetModeView = (1<<1)
} DatasheetMode;

typedef enum DatasheetAccessoryStyles {
    DatasheetAccessoryNone,
    DatasheetAccessoryDisclosure
} DatasheetAccessoryStyle;

typedef BOOL(^ValidatorBlock)(DatasheetItem* item);
typedef BOOL(^ChangeValidatorBlock)(id oldValue, id newValue);

@protocol DatasheetControllerDelegate <NSObject>

- (void) controllerDidChangeObject: (DatasheetController*) controller;

- (void) controllerWillChangeContent: (DatasheetController*) controller;
- (void) controller: (DatasheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath;
- (void) controller: (DatasheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type;
- (void) controllerDidChangeContent: (DatasheetController*) controller;

- (void) controller: (DatasheetController*) controller didChangeBackgroundImage: (UIImage*) image;

- (void) controllerDidFinish:(DatasheetController *)controller;
- (void) controllerDidChangeTitle: (DatasheetController*) controller;

- (void) makeFirstResponder: (NSIndexPath*) indexPath;

@end

@protocol DatasheetItemDelegate <NSObject>

- (BOOL) isItemVisible: (DatasheetItem*) item;
- (BOOL) isItemEnabled: (DatasheetItem*) item;
- (id) valueForItem: (DatasheetItem*) item;

@optional

- (NSString*) cellIdentifierForItem: (DatasheetItem*) item;
- (NSString*) titleForItem: (DatasheetItem*) item;
- (UIColor*) titleTextColorForItem: (DatasheetItem*) item;
- (DatasheetAccessoryStyle) accessoryStyleForItem: (DatasheetItem*) item;

- (NSString*) valueFormatStringForItem: (DatasheetItem*) item;
- (NSString*) valuePlaceholderForItem: (DatasheetItem*) item;

- (NSString*) segueIdentifierForItem: (DatasheetItem*) item;
- (id) targetForItem: (DatasheetItem*) item;
- (SEL) actionForItem: (DatasheetItem*) item;
- (BOOL) isItemDeletable: (DatasheetItem*) item;

- (NSString*) deleteButtonTitleForItem: (DatasheetItem*) item;

@end

@protocol DatasheetSectionDelegate <NSObject>

- (NSUInteger) numberOfItemsInSection: (DatasheetSection*) section;
- (DatasheetItem*) section: (DatasheetSection*) section itemAtIndex: (NSUInteger) index;

- (NSAttributedString*) titleForSection: (DatasheetSection*) section;

@end

@interface DatasheetItem : NSObject

@property (nonatomic, strong)   NSString              * identifier;
@property (nonatomic, strong)   NSString              * cellIdentifier;
@property (nonatomic, strong)   NSString              * title;
@property (nonatomic, strong)   UIColor               * titleTextColor;
@property (nonatomic, assign)   DatasheetAccessoryStyle accessoryStyle;

@property (nonatomic, strong)   NSString              * valuePath;
@property (nonatomic, strong)   NSString              * valueFormatString;
@property (nonatomic, strong)   NSString              * valuePlaceholder;
@property (nonatomic, strong)   NSArray               * dependencyPaths;

@property (nonatomic, strong)   NSString              * segueIdentifier;
@property (nonatomic, weak)     id                      target;
@property (nonatomic, assign)   SEL                     action;
@property (nonatomic, assign)   BOOL                    isBusy;

@property (nonatomic, assign)   NSUInteger              visibilityMask;
@property (nonatomic, assign)   NSUInteger              enabledMask;

@property (nonatomic, readonly) BOOL                    isVisible;
@property (nonatomic, readonly) BOOL                    isEnabled;
@property (nonatomic, assign)   BOOL                    isDeletable;
@property (nonatomic, strong)   NSString              * deleteButtonTitle;
@property (nonatomic, readonly) BOOL                    isValid;
@property (nonatomic, copy)     ValidatorBlock          validator;
@property (nonatomic, copy)     ChangeValidatorBlock    changeValidator;

@property (nonatomic, strong) id                        currentValue;
@property (nonatomic, readonly) BOOL                    currentValueIsModified;

@property (nonatomic, weak) id<DatasheetItemDelegate>   delegate;

+ (id) datasheetItem;

- (void) clearCurrentValue;

@end

@interface DatasheetSection : NSObject <NSCopying>
{
    NSArray * _items;
}

@property (nonatomic, strong) NSString           * identifier;
@property (nonatomic, strong) NSAttributedString * title;
@property (nonatomic, assign) NSTextAlignment      titleTextAlignment;
@property (nonatomic, strong) NSAttributedString * footerText;
@property (nonatomic, strong) NSString           * headerViewIdentifier;
@property (nonatomic, strong) NSString           * footerViewIdentifier;
@property (nonatomic, readonly) NSUInteger         count;

@property (nonatomic, weak) id<DatasheetSectionDelegate> delegate;

+ (id) datasheetSectionWithIdentifier: (NSString*) identifier;

- (void) setItems: (NSArray*) items;
- (id) objectAtIndexedSubscript: (NSUInteger) index;

@end

@interface DatasheetController : NSObject <DatasheetItemDelegate>

@property (nonatomic,strong) id inspectedObject;

@property (nonatomic, strong)   NSString         * title;
@property (nonatomic, strong)   NSString         * backButtonTitle;
@property (nonatomic, strong)   DatasheetSection * items;
@property (nonatomic, readonly) DatasheetSection * currentItems;
@property (nonatomic, assign)   BOOL               isEditable;
@property (nonatomic, assign)   BOOL               isCancelable;
@property (nonatomic, readonly) DatasheetMode      mode;
@property (nonatomic, readonly) BOOL               isEditing;
@property (nonatomic, readonly) BOOL               allItemsValid;

@property (nonatomic, weak)     UIViewController<DatasheetControllerDelegate> * delegate;

- (BOOL) isItemVisible: (DatasheetItem*) item;
- (BOOL) isItemEnabled: (DatasheetItem*) item;

- (id) valueForItem: (DatasheetItem*) item;

- (DatasheetItem*) itemWithIdentifier: (NSString*) titleKey cellIdentifier: (NSString*) cellIdentifier;
- (id) itemAtIndexPath: (NSIndexPath*) indexPath;

- (NSArray*) buildSections;
- (void) editModeChanged: (id) sender;
- (void) cancelEditing: (id) sender;
- (void) commonInit;
- (void) didUpdateInspectedObject;

- (UIView*) tableHeaderView;
- (UIImage*) updateBackgroundImage;
- (void) backgroundImageChanged;
- (void)prepareForSegue:(UIStoryboardSegue *)segue withItem: (DatasheetItem*) item sender:(id)sender;
- (void) didChangeValueForItem: (DatasheetItem*) item;
- (void) inspectedObjectWillChange;
- (void) inspectedObjectDidChange;
- (void) updateItem: (DatasheetItem*) item;
- (void) updateCurrentItems;

- (void) removeObjectObservers;
- (void) addObjectObservers;
- (void) titleChanged;

- (void) registerCellClasses: (DatasheetViewController*) viewController;
- (void) configureCell: (id) cell withItem: (DatasheetItem*) item atIndexPath: (NSIndexPath*) indexPath;

- (void) editRemoveItem: (DatasheetItem*) item;
- (void) editInsertItem: (DatasheetItem*) item;

//- (void) didInsertItem: (DatasheetItem*) item inSection: (DatasheetSection*) section;
//- (void) didRemoveItem: (DatasheetItem*) item inSection: (DatasheetSection*) section;

- (NSIndexPath*) indexPathForItem: (id) aItem;

@end
