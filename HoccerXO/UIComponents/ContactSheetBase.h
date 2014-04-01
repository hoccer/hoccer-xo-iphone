//
//  ContactSheetController.h
//  HoccerXO
//
//  Created by David Siegel on 25.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DatasheetController.h"

@interface ContactSheetBase : DatasheetController

@property (nonatomic, readonly) DatasheetSection * commonSection;
@property (nonatomic, readonly) DatasheetItem    * nicknameItem;
@property (nonatomic, readonly) DatasheetItem    * keyItem;

@property (nonatomic, readonly) DatasheetSection * destructiveSection;
@property (nonatomic, readonly) DatasheetItem    * destructiveButton;

- (void) addUtilitySections: (NSMutableArray*) sections;


@end
