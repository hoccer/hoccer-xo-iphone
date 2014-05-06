//
//  ModalTaskHUD.m
//  HoccerXO
//
//  Created by David Siegel on 06.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ModalTaskHUD.h"

#import "HXOUI.h"

static const CGFloat kAnimationDuration = 0.3;

@interface ModalTaskHUD ()

@property (nonatomic, strong) UILabel * titleLabel;
@property (nonatomic, strong) UIView  * hud;
@property (nonatomic, strong) UIView  * spinner;

@end

@implementation ModalTaskHUD

@dynamic title;

+ (id) modalTaskHUDWithTitle: (NSString*) title {
    ModalTaskHUD * hud = [[ModalTaskHUD alloc] initWithFrame: [UIApplication sharedApplication].delegate.window.bounds];
    hud.title = title;
    return hud;
}

- (id)initWithFrame: (CGRect) frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //self.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundColor = [UIColor colorWithWhite: 0 alpha: 0.4];

    self.hud = [[UIView alloc] initWithFrame: CGRectZero];
    self.hud.translatesAutoresizingMaskIntoConstraints = NO;
    self.hud.backgroundColor = [UIColor colorWithWhite: 0 alpha: 0.75];
    self.hud.layer.cornerRadius = kHXOGridSpacing;
    [self addSubview: self.hud];

    self.titleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"busy";
    self.titleLabel.textColor = [UIColor whiteColor];
    [self.hud addSubview: self.titleLabel];

    NSString * format = [NSString stringWithFormat: @"H:|-%f-[title]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.hud addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"title": self.titleLabel}]];

    format = [NSString stringWithFormat: @"V:|-%f-[title]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.hud addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: @{@"title": self.titleLabel}]];

    [self addConstraint: [NSLayoutConstraint constraintWithItem: self.hud attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self attribute:NSLayoutAttributeCenterX multiplier: 1 constant: 0]];
    [self addConstraint: [NSLayoutConstraint constraintWithItem: self.hud attribute: NSLayoutAttributeCenterY relatedBy: NSLayoutRelationEqual toItem: self attribute:NSLayoutAttributeCenterY multiplier: 1 constant: 0]];
}

- (void) showInView: (UIView*) view {
    self.alpha = 0;
    [[UIApplication sharedApplication].delegate.window addSubview: self];
    [UIView animateWithDuration: kAnimationDuration animations:^{
        self.alpha = 1;
    }];
}

- (void) dismiss {
    [UIView animateWithDuration: kAnimationDuration animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void) setTitle:(NSString *)title {
    self.titleLabel.text = title;
}

- (NSString*) title {
    return self.titleLabel.text;
}

@end
