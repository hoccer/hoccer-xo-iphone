//
//  DatasheetFooterTextView.m
//  HoccerXO
//
//  Created by David Siegel on 27.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetFooterTextView.h"

#import "HXOHyperLabel.h"

@implementation DatasheetFooterTextView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.label = [[HXOHyperLabel alloc] initWithFrame: self.bounds];
    [self addSubview: self.label];
}

+ (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

- (NSString*) reuseIdentifier {
    return NSStringFromClass([self class]);
}

@end
