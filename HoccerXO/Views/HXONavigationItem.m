//
//  HXONavigationItem.m
//  HoccerXO
//
//  Created by David Siegel on 18.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXONavigationItem.h"

static const CGFloat kHXONavigationTitleItemSize = 30;
static const CGFloat kHXONavigationTitleItemPadding = 0;

@implementation HXONavigationTitleView

- (id) initWithLogo: (BOOL) showLogo {
    self = [super initWithFrame: CGRectMake(0, 0, 30, 30)];
    if (self != nil) {
        if (showLogo) {
            _logo = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar_logo"]];
            _logo.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            _logo.contentMode = UIViewContentModeCenter;
            CGRect frame = _logo.frame;
            frame.origin.y = (30 - frame.size.height) / 2;
            _logo.frame = frame;
            [self addSubview: _logo];
        } else {
            _titleLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 30, 30)];
            _titleLabel.font = [UIFont boldSystemFontOfSize: 18];
            _titleLabel.textColor = [UIColor whiteColor];
            _titleLabel.backgroundColor = [UIColor clearColor];
            [self addSubview: _titleLabel];
        }
        CGRect controlFrame = CGRectMake(0, 0, kHXONavigationTitleItemSize, kHXONavigationTitleItemSize);
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame: controlFrame];
        _activityIndicator.hidesWhenStopped = YES;
        //[_activityIndicator startAnimating];
        [self addSubview: _activityIndicator];

        _promptButton = [UIButton buttonWithType: UIButtonTypeCustom];
        _promptButton.frame = controlFrame;
        _promptButton.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview: _promptButton];
    }
    return self;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    NSLog(@"HXONavigationTitleView layoutSubview");
    //[_titleLabel sizeToFit];
    CGRect frame = _logo != nil ? _logo.frame : _titleLabel.frame;
    CGFloat buttonX = frame.origin.x + frame.size.width + kHXONavigationTitleItemPadding;
    frame = _promptButton.frame;
    frame.origin.x = buttonX;
    _promptButton.frame = frame;
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
    result.height = MAX(result.height, kHXONavigationTitleItemSize);
    return result;
}

@end

@implementation HXONavigationItem

#if 0

- (void) setTitle:(NSString *)title {
    [super setTitle: title];

    _customTitleView.titleLabel.text = title;
    [_customTitleView setNeedsLayout];
}

- (void) awakeFromNib {
    [super awakeFromNib];
    NSLog(@"HXONavigationItem awakeFromNib logo: %d", self.showLogo);
    _customTitleView = [[HXONavigationTitleView alloc] initWithLogo: self.showLogo];
    self.titleView = _customTitleView;
    [_customTitleView.promptButton addTarget: self action: @selector(promptButtonPressed:) forControlEvents: UIControlEventTouchUpInside];
}

- (IBAction) promptButtonPressed: (id) sender {
    NSLog(@"Button pressed");
}

#endif

@end

