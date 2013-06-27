//
//  HXOActionSheet.m
//  HoccerToolKit
//
//  Created by David Siegel on 26.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOActionSheet.h"

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

@end
