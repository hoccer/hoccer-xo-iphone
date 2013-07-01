//
//  HXOActionSheet.m
//  HoccerToolKit
//
//  Created by David Siegel on 26.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOActionSheet.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kHXOASButtonSpacing = 10;

@implementation HXOActionSheet

- (id) initWithTitle:(NSString *)title delegate:(id <HXOActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
{
    self = [super initWithTitle: title];
    if (self != nil) {
        self.delegate = delegate;
        _destructiveButtonIndex = -1;
        _cancelButtonIndex = -1;
        _firstOtherButtonIndex = -1;
        _buttonTitles = [[NSMutableArray alloc] init];
        if (destructiveButtonTitle != nil) {
            _destructiveButtonIndex = 0;
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
            _cancelButtonIndex = _buttonTitles.count;
            [_buttonTitles addObject: cancelButtonTitle];
        }

        CGFloat capWidth = 9;
        _destructiveButtonBackgroundImage = [[UIImage imageNamed:@"actionsheet_btn_red"] stretchableImageWithLeftCapWidth: capWidth topCapHeight: 0];
        _cancelButtonBackgroundImage      = [[UIImage imageNamed: @"actionsheet_btn_dark"] stretchableImageWithLeftCapWidth: capWidth topCapHeight: 0];
        _otherButtonBackgroundImage       = [[UIImage imageNamed: @"actionsheet_btn_light"] stretchableImageWithLeftCapWidth: capWidth topCapHeight: 0];
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

- (CGFloat) layoutControls: (UIView*) container maxFrame:(CGRect) maxFrame {
    CGFloat buttonHeight = _otherButtonBackgroundImage.size.height;
    CGFloat height = _buttonTitles.count * buttonHeight + (_buttonTitles.count - 1) * kHXOASButtonSpacing;
    if (height <= maxFrame.size.height) {
        NSLog(@"========= maxSize %@ with buttons", NSStringFromCGRect(maxFrame));
        if (_buttonViews == nil) {
            _buttonViews = [[NSMutableArray alloc] initWithCapacity: _buttonTitles.count];
            for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
                UIButton * button = [UIButton buttonWithType: UIButtonTypeCustom];
                button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                button.titleLabel.font = [UIFont boldSystemFontOfSize: [UIFont buttonFontSize]];
                button.tag = i;
                [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
                if (i == _destructiveButtonIndex) {
                    [button setBackgroundImage: _destructiveButtonBackgroundImage forState: UIControlStateNormal];
                    [button setTitleColor: [UIColor whiteColor] forState: UIControlStateNormal];
                } else if (i == _cancelButtonIndex) {
                    [button setBackgroundImage: _cancelButtonBackgroundImage forState: UIControlStateNormal];
                    [button setTitleColor: [UIColor whiteColor] forState: UIControlStateNormal];
                } else {
                    [button setBackgroundImage: _otherButtonBackgroundImage forState: UIControlStateNormal];
                    [button setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
                }
                [button setTitle: _buttonTitles[i] forState: UIControlStateNormal];
                [container addSubview: button];
                [_buttonViews addObject: button];
            }
        }
        CGRect buttonFrame = maxFrame;
        buttonFrame.size.height = buttonHeight;
        for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
            ((UIButton*)_buttonViews[i]).frame = buttonFrame;
            buttonFrame.origin.y += buttonHeight + kHXOASButtonSpacing;
        }
        if (_buttonTable != nil) {
            [_buttonTable removeFromSuperview];
            _buttonTable = nil;
        }
    } else {
        NSLog(@"========= maxSize %@ with table", NSStringFromCGRect(maxFrame));
        height = maxFrame.size.height;
        if (_buttonViews != nil) {
            for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
                [(UIButton*)_buttonViews[i] removeFromSuperview];
            }
            _buttonViews = nil;
        }
        _buttonTable = [[UITableView alloc] initWithFrame:maxFrame style: UITableViewStylePlain];
        _buttonTable.layer.cornerRadius = 10.0;
        _buttonTable.layer.borderWidth = 3;
        [_buttonTable registerClass: [UITableViewCell class] forCellReuseIdentifier: @"cell"];
        _buttonTable.delegate = self;
        _buttonTable.dataSource = self;
        [container addSubview: _buttonTable];
    }
    return height;
}

- (CGSize)  controlSize: (CGSize) size {
    size.height = MIN(_buttonTitles.count * _otherButtonBackgroundImage.size.height + (_buttonTitles.count - 1) * kHXOASButtonSpacing, size.height);
    return size;
}

- (void) buttonTapped: (UIButton*) sender {
    [self dismissWithClickedButtonIndex: sender.tag animated: YES];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    [self dismissAnimated: animated completion:^{
        if ([self.delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)]) {
            [self.delegate actionSheet: self clickedButtonAtIndex: buttonIndex];
        }
    }];
}

#pragma mark - Table View Delegate and Datasource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _buttonTitles.count;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [_buttonTable dequeueReusableCellWithIdentifier:@"cell" forIndexPath: indexPath];
    cell.textLabel.text = _buttonTitles[indexPath.row];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self dismissWithClickedButtonIndex: indexPath.row animated: YES];
}

@end
