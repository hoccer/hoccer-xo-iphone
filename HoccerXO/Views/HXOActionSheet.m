//
//  HXOActionSheet.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOActionSheet.h"


static const CGFloat kHXOASHPadding = 20;
static const CGFloat kHXOASVPadding = 10;

@implementation HXOActionSheet

- (id) initWithTitle:(NSString *)title delegate:(id <HXOActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [super init];
    if (self != nil) {
        self.title = title;
        self.delegate = delegate;
        self.destructiveButtonIndex = -1;
        self.cancelButtonIndex = -1;
        _firstOtherButtonIndex = -1;
        _buttonTitles = [[NSMutableArray alloc] init];
        if (destructiveButtonTitle != nil) {
            self.destructiveButtonIndex = 0;
            [_buttonTitles addObject: destructiveButtonTitle];
        }
        va_list otherButtons;
        va_start(otherButtons, otherButtonTitles);
        NSString * buttonTitle;
        while (otherButtonTitles && (buttonTitle = va_arg(otherButtons, NSString * ))) {
            if (_firstOtherButtonIndex == -1) {
                _firstOtherButtonIndex = _buttonTitles.count;
            }
            [_buttonTitles addObject: buttonTitle];
        }
        va_end(otherButtons);
        if (cancelButtonTitle != nil) {
            self.cancelButtonIndex = _buttonTitles.count;
            [_buttonTitles addObject: cancelButtonTitle];
        }
    }
    return self;
}

- (NSInteger) addButtonWithTitle: (NSString*) title {
    NSInteger index = _buttonTitles.count;
    [_buttonTitles addObject: title];
    return index;
}

- (NSInteger) numberOfButtons {
    return _buttonTitles.count;
}

- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex {
    return _buttonTitles[buttonIndex];
}

- (void) setCancelButtonIndex:(NSInteger)cancelButtonIndex {
    _cancelButtonIndex = cancelButtonIndex;
    [self updateFirstOtherButtonIndex];
}

- (void) setDestructiveButtonIndex:(NSInteger)destructiveButtonIndex {
    _destructiveButtonIndex = destructiveButtonIndex;
    [self updateFirstOtherButtonIndex];
}

- (void) updateFirstOtherButtonIndex {
    // TODO
}

- (void)showInView:(UIView *)view {
    UIView * rootView = view.window.rootViewController.view;
    _initialOrientation = UIDevice.currentDevice.orientation;
    _coverView = [[UIView alloc] initWithFrame: rootView.bounds];
    self.frame = rootView.bounds;
    self.alpha = 0;
    self.backgroundColor = [UIColor blackColor];
    [rootView addSubview: self];

    CGRect frame = rootView.bounds;
    frame.size.height = 200;
    frame.origin.y += rootView.bounds.size.height;
    _actionView = [[UIView alloc] initWithFrame: frame];
    _actionView.backgroundColor = [UIColor blackColor];
    [rootView addSubview: _actionView];

    UILabel * titleLabel = [self createTitleLabelOfWidth: rootView.bounds.size.width];
    [_actionView addSubview: titleLabel];

    [UIView animateWithDuration: 0.3 animations:^{
        self.alpha = 0.5;
        CGRect frame = _actionView.frame;
        frame.origin.y -= frame.size.height;
        _actionView.frame = frame;
    }];
}

- (UILabel*) createTitleLabelOfWidth: (CGFloat) width {
    CGFloat w = width - 2 * kHXOASHPadding;
    UILabel * label = [[UILabel alloc] init];
    label.textColor = [UIColor whiteColor];
    label.text = self.title;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    CGRect frame = label.frame;
    frame.origin.x = kHXOASHPadding;
    frame.origin.y = kHXOASVPadding;
    frame.size.width = w;
    label.frame = frame;
    label.textAlignment = NSTextAlignmentCenter;
    [label sizeToFit];
    return label;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
