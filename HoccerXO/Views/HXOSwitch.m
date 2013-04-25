//
//  HXOSwitch.m
//  HoccerXO
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOSwitch.h"

@implementation HXOSwitch

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self setMinimumTrackImage: [[UIImage imageNamed:@"switch_left_track"] stretchableImageWithLeftCapWidth:4 topCapHeight:0] forState:UIControlStateNormal];
        [self setMaximumTrackImage: [[UIImage imageNamed:@"switch_right_track"] stretchableImageWithLeftCapWidth:1 topCapHeight:0] forState:UIControlStateNormal];
        [self setThumbImage: [UIImage imageNamed:@"switch_thumb"] forState:UIControlStateNormal];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        UITapGestureRecognizer * tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        tapRecognizer.numberOfTapsRequired = 1;
        tapRecognizer.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:tapRecognizer];
        self.value = 0;
    }
    return self;
}

- (void) tapped: (id) sender {
    if (self.value < 0.5) {
        [self setValue: 1.0 animated: YES];
    } else {
        [self setValue: 0.0 animated: YES];
    }
}

- (BOOL) boolValue {
    return self.value > 0.5;
}

- (void) setBoolValue:(BOOL)boolValue {
    self.value = boolValue ? 1.0 : 0.0;
}
@end
