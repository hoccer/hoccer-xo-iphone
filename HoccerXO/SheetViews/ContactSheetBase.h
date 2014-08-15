//
//  ContactSheetController.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DatasheetController.h"
#import "HXOClientProtocol.h"
#import "AttachmentPickerController.h"

@class AvatarView;

@interface ContactSheetBase : DatasheetController <UINavigationControllerDelegate,UIImagePickerControllerDelegate>

@property (nonatomic, readonly) id<HXOClientProtocol> client;

@property (nonatomic, readonly) DatasheetSection    * commonSection;
@property (nonatomic, readonly) DatasheetItem       * nicknameItem;
@property (nonatomic, readonly) DatasheetItem       * keyItem;

@property (nonatomic, readonly) AvatarView          * avatarView;
@property (nonatomic, readonly) DatasheetItem       * avatarItem;

@property (nonatomic, readonly) DatasheetSection    * destructiveSection;
@property (nonatomic, readonly) DatasheetItem       * destructiveButton;

@property (nonatomic, readonly) DatasheetItem       * relationshipItem;

- (void) addUtilitySections: (NSMutableArray*) sections;


@end
