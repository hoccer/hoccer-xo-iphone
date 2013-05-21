//
//  HXONavigationItem.m
//  HoccerXO
//
//  Created by David Siegel on 18.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXONavigationItem.h"

static const CGFloat kHXONavigationTitleItemSize = 18;
static const CGFloat kHXONavigationTitleItemPadding = 10;

@implementation HXONavigationTitleView

- (id) initWithLogo: (BOOL) showLogo {
    self = [super init];
    if (self != nil) {
        if (showLogo) {
            _logo = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar_logo"]];
            _logo.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin |UIViewAutoresizingFlexibleRightMargin;
            //_logo.contentMode = UIViewContentModeCenter;
            [self addSubview: _logo];
        } else {
            _titleLabel = [[UILabel alloc] init];
            [self addSubview: _titleLabel];
        }
        CGRect indicatorFrame = CGRectMake(0, 0, kHXONavigationTitleItemSize, kHXONavigationTitleItemSize);
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame: indicatorFrame];
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin;
//        _activityIndicator.userInteractionEnabled = YES;
        _activityIndicator.hidesWhenStopped = YES;
        [_activityIndicator startAnimating];
        [self addSubview: _activityIndicator];
        _errorIndicator = [[UIImageView alloc] init];
        [self addSubview: _errorIndicator];
    }
    return self;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    NSLog(@"HXONavigationTitleView layoutSubview");
    CGRect frame = _logo != nil ? _logo.frame : _titleLabel.frame;
    CGFloat indicatorX = frame.origin.x + frame.size.width + kHXONavigationTitleItemPadding;
    frame = _activityIndicator.frame;
    frame.origin.x = indicatorX;
    _activityIndicator.frame = frame;
}

- (CGSize) sizeThatFits:(CGSize)size {
    CGSize result;
    if (_logo) {
        result = _logo.bounds.size;
    } else {
        result = [_titleLabel sizeThatFits: size];
    }
    result.width += 2 * (kHXONavigationTitleItemPadding + kHXONavigationTitleItemSize);
    NSLog(@"sizeThatFits: %@ result: %@", NSStringFromCGSize(size), NSStringFromCGSize(result));
    return result;
}

@end

@implementation HXONavigationItem

- (void) setTitle:(NSString *)title {
    [super setTitle: title];
    _customTitleView.titleLabel.text = title;
    [_customTitleView setNeedsLayout];
}

- (void) awakeFromNib {
    NSLog(@"HXONavigationItem awakeFromNib logo: %d", self.showHoccerLogo);
    _customTitleView = [[HXONavigationTitleView alloc] initWithLogo: self.showHoccerLogo];
    self.titleView = _customTitleView;
}

@end

