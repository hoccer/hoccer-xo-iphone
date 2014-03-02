//
//  HXOAvatarButton.m
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOAvatarButton.h"

@interface HXOAvatarButton ()

@property (nonatomic,strong) CALayer* ledLayer;

@end

@implementation HXOAvatarButton

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.imageView.clipsToBounds = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;

    self.ledSize = 5;
    self.ledLayer = [CALayer layer];
    self.ledLayer.backgroundColor = [UIColor redColor].CGColor;
    self.ledLayer.opacity = 0;
    [self.layer addSublayer: self.ledLayer];
}

- (void) layoutSublayersOfLayer:(CALayer *)layer {
    [super layoutSublayersOfLayer:layer];

    if (layer == self.layer) {
        self.ledLayer.cornerRadius = 0.5 * self.ledSize;
        self.ledLayer.frame = CGRectMake(self.bounds.size.width - self.ledSize, 0, self.ledSize, self.ledSize);
    }
    self.imageView.layer.cornerRadius = 0.5 * self.imageView.frame.size.width;
}

- (void) setShowLed:(BOOL)showLed {
    _showLed = showLed;
    self.ledLayer.opacity = showLed ? 1.0 : 0.0;
}

@end
