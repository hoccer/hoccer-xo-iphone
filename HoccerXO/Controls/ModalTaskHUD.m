//
//  ModalTaskHUD.m
//  HoccerXO
//
//  Created by David Siegel on 06.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ModalTaskHUD.h"

#import "HXOUI.h"
#import "HXOActivityIndicatorView.h"

static const CGFloat kAnimationDuration = 0.3;

@interface ModalTaskHUD ()

@property (nonatomic, strong) UILabel                  * titleLabel;
@property (nonatomic, strong) UIView                   * hud;
@property (nonatomic, strong) HXOActivityIndicatorView * spinner;

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

    self.hud = [[UIView alloc] initWithFrame: CGRectZero];
    self.hud.translatesAutoresizingMaskIntoConstraints = NO;
    self.hud.backgroundColor = [UIColor colorWithWhite: 0 alpha: 0.8];
    self.hud.layer.cornerRadius = kHXOGridSpacing;
    [self addSubview: self.hud];

    CGFloat spinnerSize = 6 * kHXOGridSpacing;
    self.spinner = [[HXOActivityIndicatorView alloc] initWithFrame: CGRectMake(0, 0, spinnerSize, spinnerSize)];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.hud addSubview: self.spinner];

    self.titleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"busy";
    self.titleLabel.textColor = [UIColor whiteColor];
    [self.hud addSubview: self.titleLabel];

    NSDictionary * views = @{@"title": self.titleLabel, @"spinner": self.spinner};

    NSString * format = [NSString stringWithFormat: @"H:|-%f-[title]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.hud addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self addConstraint: [NSLayoutConstraint constraintWithItem: self.spinner attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self attribute:NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    format = [NSString stringWithFormat: @"V:|-%f-[spinner]-%f-[title]-%f-|", kHXOCellPadding, kHXOGridSpacing, kHXOCellPadding];
    [self.hud addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    [self.hud addConstraint: [NSLayoutConstraint constraintWithItem: self.spinner attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: self.spinner attribute: NSLayoutAttributeHeight multiplier: 1 constant: 0]];

    [self addConstraint: [NSLayoutConstraint constraintWithItem: self.hud attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self attribute:NSLayoutAttributeCenterX multiplier: 1 constant: 0]];
    [self addConstraint: [NSLayoutConstraint constraintWithItem: self.hud attribute: NSLayoutAttributeCenterY relatedBy: NSLayoutRelationEqual toItem: self attribute:NSLayoutAttributeCenterY multiplier: 1 constant: 0]];
}

- (void) show {
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

- (void) setDimColor: (UIColor*) dimColor {
    self.hud.backgroundColor = dimColor;
}

- (UIColor*) dimColor {
    return self.hud.backgroundColor;
}

@end
