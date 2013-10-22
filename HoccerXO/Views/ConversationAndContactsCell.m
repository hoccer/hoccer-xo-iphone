//
//  ConversationAndContactsCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationAndContactsCell.h"
#import "InsetImageView.h"

#import "AssetStore.h"

@implementation ConversationAndContactsCell

- (void) awakeFromNib {
    self.backgroundView = [[UIImageView alloc] initWithImage: [AssetStore stretchableImageNamed: [self backgroundName] withLeftCapWidth: 1.0 topCapHeight: 0]];
    //self.avatar.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];
    //self.avatar.borderColor = [UIColor colorWithWhite: 0 alpha: 0.6];

}

- (void) engraveLabel: (UILabel*) label {
    label.textColor = [UIColor darkGrayColor];
    label.shadowColor = [UIColor colorWithWhite: 1.0 alpha: 0.5];
    label.shadowOffset = CGSizeMake(0.0, 1.0);

}

- (NSString*) backgroundName {
    return nil;
}
@end
