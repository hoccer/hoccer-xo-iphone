//
//  ContactSheet.h
//  HoccerXO
//
//  Created by David Siegel on 31.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetBase.h"

@interface ContactSheetController : ContactSheetBase

<DatasheetSectionDataSource, DatasheetSectionDelegate, NSFetchedResultsControllerDelegate>

@end
