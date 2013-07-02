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
static const CGFloat kHXOASCancelButtonSpacing = 20;

@interface HXOASOtherButtonCell : UITableViewCell

@end

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

        _otherButtonCellClass = [HXOASOtherButtonCell class];
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

- (void) setActionSheetStyle:(HXOSheetStyle)actionSheetStyle {
    self.sheetStyle = actionSheetStyle;
}

- (HXOSheetStyle) actionSheetStyle {
    return self.sheetStyle;
}

- (void) updateFirstOtherButtonIndex {
    // TODO
}

- (CGFloat) layoutControls: (UIView*) container maxFrame:(CGRect) maxFrame {
    CGFloat buttonHeight = _otherButtonBackgroundImage.size.height;
    //CGFloat height = _buttonTitles.count * buttonHeight + (_buttonTitles.count - 1) * kHXOASButtonSpacing;
    CGFloat height = 0;
    for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
        height += [self buttonSpacing: i];
    }
    if (height <= maxFrame.size.height) {
        if (_buttonViews == nil) {
            _buttonViews = [[NSMutableArray alloc] initWithCapacity: _buttonTitles.count];
            for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
                UIButton * button = [self createButton: i];
                [container addSubview: button];
                [_buttonViews addObject: button];
            }
        }
        CGRect buttonFrame = maxFrame;
        buttonFrame.size.height = buttonHeight;
        for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
            ((UIButton*)_buttonViews[i]).frame = buttonFrame;
            buttonFrame.origin.y += [self buttonSpacing: i];
        }
        if (_buttonTable != nil) {
            [_buttonTable removeFromSuperview];
            _buttonTable = nil;
        }
        if (_tableModelDestructiveButton != nil) {
            [_tableModelDestructiveButton removeFromSuperview];
            _tableModelDestructiveButton = nil;
        }
        if (_tableModeCancelButton != nil) {
            [_tableModeCancelButton removeFromSuperview];
            _tableModeCancelButton = nil;
        }
    } else {
        height = maxFrame.size.height;
        if (_buttonViews != nil) {
            for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
                [(UIButton*)_buttonViews[i] removeFromSuperview];
            }
            _buttonViews = nil;
        }
        CGRect tableFrame = maxFrame;
        if (self.destructiveButtonIndex != -1) {
            CGFloat buttonSpacing = [self buttonSpacing: self.destructiveButtonIndex];
            tableFrame.origin.y += buttonSpacing;
            tableFrame.size.height -= buttonSpacing;
        }
        if (self.cancelButtonIndex != -1) {
            tableFrame.size.height -= [self buttonSpacing: self.cancelButtonIndex - 1];
        }
        _buttonTable = [[UITableView alloc] initWithFrame:tableFrame style: UITableViewStylePlain];
        _buttonTable.layer.cornerRadius = 8.0;
        _buttonTable.layer.borderWidth = 5;
        _buttonTable.backgroundColor = [UIColor colorWithWhite: 0.8 alpha: 1.0];
        _buttonTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        _buttonTable.layer.masksToBounds = YES;
        [_buttonTable registerClass: self.otherButtonCellClass forCellReuseIdentifier: @"otherButtonCell"];
        _buttonTable.delegate = self;
        _buttonTable.dataSource = self;
        [container addSubview: _buttonTable];

        if (self.destructiveButtonIndex != -1) {
            _tableModelDestructiveButton = [self createButton: self.destructiveButtonIndex];
            CGRect buttonFrame = maxFrame;
            buttonFrame.size.height = buttonHeight;
            _tableModelDestructiveButton.frame = buttonFrame;
            [container addSubview: _tableModelDestructiveButton];
        }
        if (self.cancelButtonIndex != -1) {
            _tableModeCancelButton = [self createButton: self.cancelButtonIndex];
            CGRect buttonFrame = maxFrame;
            buttonFrame.origin.y = _buttonTable.frame.origin.y + _buttonTable.frame.size.height + kHXOASCancelButtonSpacing;
            buttonFrame.size.height = buttonHeight;
            _tableModeCancelButton.frame = buttonFrame;
            [container addSubview: _tableModeCancelButton];
        }
    }
    return height;
}

- (UIButton*) createButton: (NSUInteger) buttonIndex {
    UIButton * button = [UIButton buttonWithType: UIButtonTypeCustom];
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    button.titleLabel.font = [UIFont boldSystemFontOfSize: [UIFont buttonFontSize]];
    button.tag = buttonIndex;
    [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    if (buttonIndex == _destructiveButtonIndex) {
        [button setBackgroundImage: _destructiveButtonBackgroundImage forState: UIControlStateNormal];
        [button setTitleColor: [UIColor whiteColor] forState: UIControlStateNormal];
    } else if (buttonIndex == _cancelButtonIndex) {
        [button setBackgroundImage: _cancelButtonBackgroundImage forState: UIControlStateNormal];
        [button setTitleColor: [UIColor whiteColor] forState: UIControlStateNormal];
    } else {
        [button setBackgroundImage: _otherButtonBackgroundImage forState: UIControlStateNormal];
        [button setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    }
    [button setTitle: _buttonTitles[buttonIndex] forState: UIControlStateNormal];
    return button;
}

- (CGFloat) buttonSpacing: (NSUInteger) buttonIndex {
    CGFloat buttonHeight = _otherButtonBackgroundImage.size.height;
    if (buttonIndex == _buttonTitles.count - 1) {
        return buttonHeight;
    } else if (buttonIndex + 1 == self.cancelButtonIndex) {
        return buttonHeight + kHXOASCancelButtonSpacing;
    }
    return buttonHeight + kHXOASButtonSpacing;
}

- (CGSize)  controlSize: (CGSize) size {
    CGFloat height = 0;
    for (NSUInteger i = 0; i < _buttonTitles.count; ++i) {
        height += [self buttonSpacing: i];
    }
    size.height = MIN(height, size.height);
    return size;
}

- (void) buttonTapped: (UIButton*) sender {
    [self dismissWithClickedButtonIndex: sender.tag animated: YES];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)]) {
        [self.delegate actionSheet: self clickedButtonAtIndex: buttonIndex];
    }
    [self dismissAnimated: animated completion:^{}];
}

#pragma mark - Table View Delegate and Datasource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger cellCount = _buttonTitles.count;
    if (self.destructiveButtonIndex != -1) {
        cellCount -= 1;
    }
    if (self.cancelButtonIndex != -1) {
        cellCount -= 1;
    }
    return cellCount;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [_buttonTable dequeueReusableCellWithIdentifier:@"otherButtonCell" forIndexPath: indexPath];
    NSInteger buttonIndex = [self buttonIndexFromIndexPath: indexPath];
    cell.textLabel.text = _buttonTitles[buttonIndex];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger buttonIndex = [self buttonIndexFromIndexPath: indexPath];
    [self dismissWithClickedButtonIndex: buttonIndex animated: YES];
}

- (NSInteger) buttonIndexFromIndexPath: (NSIndexPath*) indexPath {
    NSInteger buttonIndex = indexPath.row;
    if (self.destructiveButtonIndex != -1 && self.destructiveButtonIndex <= buttonIndex) {
        buttonIndex += 1;
    }
    if (self.cancelButtonIndex != -1 && self.cancelButtonIndex <= buttonIndex) {
        buttonIndex += 1;
    }
    return buttonIndex;
}

@end

@implementation HXOASOtherButtonCell

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.textLabel.textAlignment = NSTextAlignmentCenter;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect labelFrame = self.bounds;
    labelFrame.origin.y += 2;
    labelFrame.size.height -= 4;
    self.textLabel.frame = labelFrame;
}

- (void) drawRect:(CGRect)rect {
    [super drawRect: rect];

    CGFloat y = 0.5;
    UIBezierPath * line = [UIBezierPath bezierPath];
    [line moveToPoint: CGPointMake(0, y)];
    [line addLineToPoint: CGPointMake(self.frame.size.width, y)];
    [[UIColor colorWithWhite: 0.9 alpha: 1.0] setStroke];
    [line stroke];

    y = self.frame.size.height - 0.5;
    line = [UIBezierPath bezierPath];
    [line moveToPoint: CGPointMake(0, y)];
    [line addLineToPoint: CGPointMake(self.frame.size.width, y)];
    [[UIColor colorWithWhite: 0.5 alpha: 1.0] setStroke];
    [line stroke];

}

@end
