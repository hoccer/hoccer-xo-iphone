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
        _hxoAccessoryXOffset = -1;
    }
    return self;
}

- (void) setHxoAccessoryView:(UIView *)hxoAccessoryView {
    if (_hxoAccessoryView) {
        [self.accessoryView removeObserver: self forKeyPath: @"frame"];
        self.accessoryView = nil;
    }
    _hxoAccessoryView = hxoAccessoryView;
    if (_hxoAccessoryView) {
        self.accessoryView = [[UIView alloc] initWithFrame: _hxoAccessoryView.bounds];
        //self.accessoryView.backgroundColor = [UIColor orangeColor];
        [self.accessoryView addObserver: self forKeyPath: @"frame" options: NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context: nil];
        [self.accessoryView addSubview: _hxoAccessoryView];
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isEqual: self.accessoryView] && [keyPath isEqualToString: @"frame"]) {
        [self updateAccessoryFrame];
    }
}

- (void) updateAccessoryFrame {
    CGRect frame = self.accessoryView.bounds;
    if (self.hxoAccessoryAlignment == HXOCellAccessoryAlignmentTop) {
        frame = [self convertRect: frame fromView: self.accessoryView];
        frame.origin.y = kHXOCellPadding;
        frame = [self convertRect: frame toView: self.accessoryView];
    }
    frame.origin.x += self.hxoAccessoryXOffset;
    self.hxoAccessoryView.frame = frame;
}


- (void) setHxoAccessoryAlignment:(HXOCellAccessoryAlignment)accessoryAlignment {
    _hxoAccessoryAlignment = accessoryAlignment;
    [self updateAccessoryFrame];
}

- (void) setHxoAccessoryPadding:(CGFloat)padding {
    _hxoAccessoryXOffset = padding;
    [self updateAccessoryFrame];
}
@end
