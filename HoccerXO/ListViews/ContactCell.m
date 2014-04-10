//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"
#import "HXOUI.h"
#import "HXOLabel.h"
#import "HXOUI.h"
#import "AvatarView.h"
#import "avatar_contact.h"

@interface ContactCell ()

@property (nonatomic,strong) NSArray * verticalConstraints;

@end

@implementation ContactCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleHeight;
    self.separatorInset = UIEdgeInsetsMake(0, kHXOCellPadding + [self avatarSize] + kHXOCellPadding, 0, 0);

    _titleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.autoresizingMask = UIViewAutoresizingNone;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    //_titleLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    _titleLabel.text = @"Random Joe";
    [self.contentView addSubview: _titleLabel];
    
    _subtitleLabel = [[HXOLabel alloc] initWithFrame: CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.autoresizingMask = UIViewAutoresizingNone;
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.text = @"Lorem ipsum";
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.textColor = [[HXOUI theme] lightTextColor];
    //_subtitleLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: _subtitleLabel];

    _avatar = [[AvatarView alloc] initWithFrame: CGRectMake(0, 0, [self avatarSize], [self avatarSize])];
    _avatar.autoresizingMask = UIViewAutoresizingNone;
    _avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview: _avatar];

    UIView * title = _titleLabel;
    UIView * subtitle = _subtitleLabel;
    UIView * image = _avatar;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle, image);
    
    [self addFirstRowHorizontalConstraints: views];
    
    NSString * format = [NSString stringWithFormat:  @"V:|-%f-[image]-(>=%f)-|", [self verticalPadding], [self verticalPadding]];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self preferredContentSizeChanged: nil];
}

- (CGFloat) avatarSize {
    return kHXOListAvatarSize;
}

- (CGFloat) verticalPadding {
    return kHXOCellPadding;
}

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views {
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[image]-%f-[title(>=0)]->=%f-|", kHXOCellPadding, kHXOCellPadding, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];
    format = [NSString stringWithFormat:  @"H:[image]-%f-[subtitle]->=%f-|", kHXOCellPadding, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];    
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    self.titleLabel.font = [HXOUI theme].titleFont;
    //NSLog(@"nickname size %@", NSStringFromCGSize( self.titleLabel.intrinsicContentSize));
    self.subtitleLabel.font = [HXOUI theme].smallTextFont;
    
    if (self.verticalConstraints) {
        [self.contentView removeConstraints: self.verticalConstraints];
    }
    UIView * title = self.titleLabel;
    UIView * subtitle = self.subtitleLabel;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle);
    CGFloat y = [self verticalPadding] - (self.titleLabel.font.ascender - self.titleLabel.font.capHeight);
    NSString * format = [NSString stringWithFormat: @"V:|-%f-[title]-%f-[subtitle]-(>=%f)-|", y, 0.5 * kHXOGridSpacing, [self verticalPadding]];
    self.verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                       options: 0 metrics: nil views: views];
    [self.contentView addConstraints: self.verticalConstraints];
    
    [self setNeedsLayout];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

@end
