//
//  HoccerXOTableViewCell.m
//  HoccerXO
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewCell.h"

#import "HXOUI.h"

@implementation HXOTableViewCell

+ (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self) {
        _hxoAccessoryPadding = kHXOCellPadding;
    }
    return self;
}

- (void) setHxoAccessoryView:(UIView *)hxoAccessoryView {
    if (_hxoAccessoryView) {
        [_hxoAccessoryView removeFromSuperview];
    }
    _hxoAccessoryView = hxoAccessoryView;
    if (_hxoAccessoryView) {
        self.accessoryView = [[UIView alloc] initWithFrame: _hxoAccessoryView.frame];
        //CGRect frame = _hxoAccessoryView.frame;
        //frame.origin.x = self.frame.size.width - (frame.size.width + kHXOGridSpacing);
        //_hxoAccessoryView.frame = frame;
        [self addSubview: _hxoAccessoryView];
        [self accessoryAlignmentChanged];
        [self setHxoAccessoryPadding: _hxoAccessoryPadding];
    } else {
        self.accessoryView = nil;
    }
}

- (void) accessoryAlignmentChanged {
    if (_hxoAccessoryView) {
        CGRect frame = _hxoAccessoryView.frame;
        UIViewAutoresizing mask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        switch (_hxoAccessoryAlignment) {
            case HXOCellAccessoryAlignmentCenter:
                frame.origin.y = (self.frame.size.height - _hxoAccessoryView.frame.size.height) / 2;
                mask |= UIViewAutoresizingFlexibleTopMargin;
                break;
            case HXOCellAccessoryAlignmentTop:
                frame.origin.y = kHXOCellPadding;
                break;
        }
        _hxoAccessoryView.autoresizingMask = mask;
        _hxoAccessoryView.frame = frame;
    }
}

- (void) setHxoAccessoryAlignment:(HXOCellAccessoryAlignment)accessoryAlignment {
    _hxoAccessoryAlignment = accessoryAlignment;
    [self accessoryAlignmentChanged];
}

- (void) setHxoAccessoryPadding:(CGFloat)padding {
    _hxoAccessoryPadding = padding;
    CGRect frame = self.hxoAccessoryView.frame;
    frame.origin.x = self.bounds.size.width - (frame.size.width + padding);
    self.hxoAccessoryView.frame = frame;
}
@end
