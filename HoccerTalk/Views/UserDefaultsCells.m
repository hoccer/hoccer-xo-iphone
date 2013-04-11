//
//  ProfileAvatarCell.m
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserDefaultsCells.h"
#import "AssetStore.h"

@implementation UserDefaultsCell

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textLabel.shadowColor = [UIColor whiteColor];
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.textLabel.textColor = [UIColor colorWithWhite: 0.25 alpha: 1.0];
    self.textLabel.backgroundColor = [UIColor clearColor];

}

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount {
    UIImage * image;
    if (cellCount == 1) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_single" withLeftCapWidth: 4 topCapHeight: 4];
    } else if (position == 0) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_first" withLeftCapWidth: 4 topCapHeight: 4];
    } else if (position == cellCount - 1) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_last" withLeftCapWidth: 4 topCapHeight: 4];
    } else {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg" withLeftCapWidth: 4 topCapHeight: 4];
    }
    self.backgroundView = [[UIImageView alloc] initWithImage: image];
}

@end

@implementation UserDefaultsCellAvatarPicker

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) count {
    self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
}
@end

@implementation UserDefaultsCellTextInput
@end

@implementation UserDefaultsCellSwitch

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textLabel.font = [UIFont boldSystemFontOfSize: 14];
}

@end

@implementation UserDefaultsCellInfoText

@end

@implementation UserDefaultsCellDisclosure

- (void) awakeFromNib {
    [super awakeFromNib];
    self.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"user_defaults_disclosure_arrow"]];
}


@end
