//
//  ContactQuickListSearchBar.m
//  HoccerXO
//
//  Created by David Siegel on 08.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactQuickListSearchBar.h"

@implementation ContactQuickListSearchBar

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    // TODO: make 1px wide and dont make it resizable
    self.backgroundImage = [[UIImage imageNamed: @"searchbar_bg"]  resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    UIImage *searchFieldImage = [[UIImage imageNamed:@"searchbar_input-text"]
                                 resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 15, 14)];
    [self setSearchFieldBackgroundImage:searchFieldImage forState:UIControlStateNormal];
    for (UIView *subview in self.subviews) {
        NSLog(@"=== subview: %@", subview);
        if([subview isKindOfClass: UITextField.class]){
            [(UITextField*)subview setTextColor: [UIColor whiteColor]];
        }
    }
}

- (void) layoutSubviews {
    [super layoutSubviews];
    for (UIView *subview in self.subviews) {
        NSLog(@"=== subview: %@", subview);
        if([subview isKindOfClass: UITextField.class]){
            CGRect frame = subview.frame;
            frame.origin.x += 16;
            frame.size.width -= 16;
            subview.frame = frame;
            break;
        }
    }
}

@end
