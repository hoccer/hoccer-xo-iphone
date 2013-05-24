//
//  GroupAdminCell.h
//  HoccerXO
//
//  Created by David Siegel on 24.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewCell.h"

@interface GroupAdminCell : HXOTableViewCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount;

@property (nonatomic,weak) IBOutlet UILabel * label;

@end
