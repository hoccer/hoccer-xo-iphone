//
//  AudioAttachmentCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "AttachmentInfo.h"
#import "AudioAttachmentCell.h"
#import "HXOAudioPlayer.h"
#import "HXOUI.h"
#import "HXOLabel.h"
#import "HXOUI.h"
#import "VectorArtView.h"
#import "player_icon_now_playing.h"

@interface AudioAttachmentCell ()

@property (nonatomic,strong) NSArray * verticalConstraints;

@end

@implementation AudioAttachmentCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    
    self.hxoAccessoryAlignment = HXOCellAccessoryAlignmentCenter;
    
    self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleHeight;
    //self.separatorInset = UIEdgeInsetsMake(0, kHXOCellPadding + [self avatarSize] + kHXOCellPadding, 0, 0);
    
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
    
    _artwork = [[UIImageView alloc] initWithFrame: CGRectMake(0, 0, [self artworkSize], [self artworkSize])];
    _artwork.autoresizingMask = UIViewAutoresizingNone;
    _artwork.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview: _artwork];
    
    UIView * title = _titleLabel;
    UIView * subtitle = _subtitleLabel;
    UIView * image = _artwork;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle, image);
    
    [self addFirstRowHorizontalConstraints: views];
    
    // HACK: Remove one to fix computed cell height
    NSString * format = [NSString stringWithFormat:  @"V:|-%f-[image(>=%f)]-%f-|", [self verticalPadding], [self artworkSize], [self verticalPadding] - 1];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];
    
    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.artwork attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: self.artwork attribute: NSLayoutAttributeHeight multiplier: 1 constant: 0]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self preferredContentSizeChanged: nil];
    
    [[HXOAudioPlayer sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    [self updatePlaybackState];
}

- (CGFloat) artworkSize {
    return 6 * kHXOGridSpacing;
}

- (CGFloat) verticalPadding {
    return kHXOGridSpacing;
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
    self.subtitleLabel.font = [HXOUI theme].smallTextFont;
    
    if (self.verticalConstraints) {
        [self.contentView removeConstraints: self.verticalConstraints];
    }
    UIView * title = self.titleLabel;
    UIView * subtitle = self.subtitleLabel;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle);
    CGFloat y = 2 * [self verticalPadding] - (self.titleLabel.font.ascender - self.titleLabel.font.capHeight);
    NSString * format = [NSString stringWithFormat: @"V:|-%f-[title]-%f-[subtitle]-(>=%f)-|", y, [self labelSpacing], [self verticalPadding]];
    self.verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                       options: 0 metrics: nil views: views];
    [self.contentView addConstraints: self.verticalConstraints];
    
    [self setNeedsLayout];
}

- (CGFloat) labelSpacing {
    return 0.5 * kHXOGridSpacing;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets insets = self.separatorInset;
    insets.left = self.titleLabel.frame.origin.x;
    self.separatorInset = insets;
}

- (void) dealloc {
    [[HXOAudioPlayer sharedInstance] removeObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying))];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    if ([keyPath isEqual:NSStringFromSelector(@selector(isPlaying))]) {
        [self updatePlaybackState];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void) setAttachment:(Attachment *)attachment {
    _attachment = attachment;

    if (attachment) {
        AttachmentInfo *info = [[AttachmentInfo alloc] initWithAttachment:attachment];
        self.titleLabel.text = info.audioTitle;
        self.subtitleLabel.text = info.audioArtistAndAlbum;
        
        [attachment loadImage:^(UIImage *image, NSError *error) {
            if (error == nil) {
                self.artwork.image = image;
            } else {
                NSLog(@"ERROR: Loading audio artwork image failed: %@", error);
            }
        }];
    } else {
        self.titleLabel.text = @"";
        self.subtitleLabel.text = @"";
        self.artwork.image = nil;
    }

    [self updatePlaybackState];
}

- (void) updatePlaybackState {
    HXOAudioPlayer *player = [HXOAudioPlayer sharedInstance];
    if (player.isPlaying && [player.attachment isEqual:self.attachment]) {
        self.hxoAccessoryView = [[VectorArtView alloc] initWithVectorArt: [[player_icon_now_playing alloc] init]];
    } else {
        self.hxoAccessoryView = nil;
    }
}

@end
