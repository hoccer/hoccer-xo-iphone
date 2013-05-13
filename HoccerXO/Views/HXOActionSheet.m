//
//  HXOActionSheet.m
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOActionSheet.h"

@implementation HXOActionSheet

- (id) initWithTitle:(NSString *)title delegate:(id < UIActionSheetDelegate >)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...
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
        NSString * title;
        while ((title = va_arg(otherButtons, NSString * ))) {
            if (_firstOtherButtonIndex == -1) {
                _firstOtherButtonIndex = _buttonTitles.count;
            }
            [_buttonTitles addObject: title];
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

- (void)showInView:(UIView *)view {

}

@end
