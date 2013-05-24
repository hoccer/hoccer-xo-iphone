//
//  GroupAdminCell.m
//  HoccerXO
//
//  Created by David Siegel on 24.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GroupAdminCell.h"
#import "UserDefaultsCells.h"

@implementation GroupAdminCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount {
    self.backgroundView = [[UIView alloc] init];
}

- (void) configure: (id) item {
    self.label.text = [item currentValue];
}
@end
