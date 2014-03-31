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


typedef BOOL(^ValidatorBlock)(DatasheetItem* item);

@protocol DatasheetControllerDelegate <NSObject>

- (void) controllerDidChangeObject: (DatasheetController*) controller;

- (void) controllerWillChangeContent: (DatasheetController*) controller;
- (void) controller: (DatasheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath;
- (void) controller: (DatasheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type;
- (void) controllerDidChangeContent: (DatasheetController*) controller;

- (void) controller: (DatasheetController*) controller didChangeBackgroundImage: (UIImage*) image;

@end

@interface DatasheetItem : NSObject

@property (nonatomic, strong) NSString *  identifier;
@property (nonatomic, strong) NSString *  cellIdentifier;
@property (nonatomic, strong) NSString *  title;
@property (nonatomic, strong) UIColor  *  titleTextColor;

@property (nonatomic, strong) NSString *  valuePath;
@property (nonatomic, strong) NSString *  placeholder;

@property (nonatomic, assign) NSUInteger  visibilityMask;
@property (nonatomic, assign) NSUInteger  enabledMask;

@property (nonatomic,readonly) BOOL       isVisible;
@property (nonatomic,readonly) BOOL       isEnabled;
@property (nonatomic,readonly) BOOL       isValid;
@property (nonatomic,copy) ValidatorBlock validator;

@property (nonatomic,strong) id          currentValue;

@property (nonatomic, weak) DatasheetController * delegate;

+ (id) datasheetItem;

@end

@interface DatasheetSection : NSObject <NSCopying>

@property (nonatomic, strong) NSString * identifier;
@property (nonatomic,strong) NSArray * items;
@property (nonatomic,strong) NSAttributedString * footerText;
@property (nonatomic, strong) NSString * headerViewIdentifier;
@property (nonatomic, strong) NSString * footerViewIdentifier;

+ (id) datasheetSectionWithIdentifier: (NSString*) identifier;

@end

@interface DatasheetController : NSObject

@property (nonatomic,strong) id inspectedObject;

@property (nonatomic,weak) id<DatasheetControllerDelegate> delegate;
@property (nonatomic,strong) NSArray * items;
@property (nonatomic,readonly) NSArray * currentItems;
@property (nonatomic,assign) BOOL isEditable;
@property (nonatomic,readonly) DatasheetMode mode;
@property (nonatomic,readonly) BOOL isEditing;
@property (nonatomic,readonly) BOOL allItemsValid;

- (BOOL) isItemVisible: (DatasheetItem*) item;
- (BOOL) isItemEnabled: (DatasheetItem*) item;

- (id) valueForItem: (DatasheetItem*) item;

- (DatasheetItem*) itemWithIdentifier: (NSString*) titleKey cellIdentifier: (NSString*) cellIdentifier;
- (id) itemForIndexPath: (NSIndexPath*) indexPath;


- (void) editModeChanged: (id) sender;
- (void) cancelEditing: (id) sender;
- (void) commonInit;
- (void) didUpdateInspectedObject;

- (UIView*) tableHeaderView;
- (UIImage*) updateBackgroundImage;
- (void) backgroundImageChanged;

@end
