//
//  AudioAttachmentCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "AttachmentInfo.h"
#import "MediaAttachmentCell.h"
#import "HXOAudioPlayer.h"
#import "HXOUI.h"
#import "HXOLabel.h"
#import "HXOUI.h"
#import "NSString+EnumerateRanges.h"
#import "VectorArtView.h"
#import "player_icon_now_playing.h"

@interface MediaAttachmentCell ()

@property (nonatomic,strong) NSArray * verticalConstraints;

@end

@implementation MediaAttachmentCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.hxoAccessoryAlignment = HXOCellAccessoryAlignmentCenter;
    self.multipleSelectionBackgroundView = [[UIView alloc] init];
    self.multipleSelectionBackgroundView.backgroundColor = [UIColor clearColor];
    
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
    //_artwork.contentMode = UIViewContentModeScaleAspectFill;
    _artwork.contentMode = UIViewContentModeScaleAspectFit;
    
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
    if (attachment == _attachment) {
        // This is particularly important to break an infinite loop where [attachment
        // loadPreviewImageIntoCacheWithCompletion] modifies the attachment itself,
        // causing this method to be called again (through NSFetchedResultsControllerDelegate
        // updates).

        return;
    }

    _attachment = attachment;

    if (attachment) {
        AttachmentInfo *info = [AttachmentInfo infoForAttachment:attachment];
        
        if ([attachment.mediaType isEqualToString:@"audio"]) {
            if ([attachment.humanReadableFileName hasPrefix:@"recording"]) {
                self.titleLabel.text = [NSString stringWithFormat:@"%@ %@", info.duration, info.dataSize];
                self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"attachment_type_audio_recording", nil),info.creationDate];
            } else {
                self.titleLabel.text = info.audioTitle;
                self.subtitleLabel.text = info.audioArtistAndAlbum;
            }
        } else if ([attachment.mediaType isEqualToString:@"video"]) {
            self.titleLabel.text = [NSString stringWithFormat:@"%@ / %@", info.duration, info.dataSize];
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@", info.typeDescription, info.creationDate];;
        } else if ([attachment.mediaType isEqualToString:@"image"]) {
            self.titleLabel.text = [NSString stringWithFormat:@"%@ / %@",  info.frameSize, info.dataSize];
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@", info.typeDescription, info.creationDate];;
        } else if ([attachment.mediaType isEqualToString:@"geolocation"]) {
            self.titleLabel.text = [NSString stringWithFormat:@"%@", info.location];
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"attachment_type_geolocation",nil), info.creationDate];;
        } else if ([attachment.mediaType isEqualToString:@"vcard"]) {
            self.titleLabel.text = [NSString stringWithFormat:@"%@", info.vcardPreviewName];
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"attachment_type_vcard",nil), info.creationDate];;
        } else if ([attachment.mediaType isEqualToString:@"data"]) {
            self.titleLabel.text = [NSString stringWithFormat:@"%@ %@", info.filename, info.dataSize];
            self.subtitleLabel.text = [NSString stringWithFormat:@"%@ %@", info.typeDescription, info.creationDate];;
        }

        if (([attachment.mediaType isEqualToString:@"audio"] && ![attachment.humanReadableFileName hasPrefix:@"recording"])||
            [attachment.mediaType isEqualToString:@"video"] ||
            [attachment.mediaType isEqualToString:@"image"] )
        {
            self.artwork.image = attachment.previewImage;
            if (!attachment.previewImage) {
                [attachment loadPreviewImageIntoCacheWithCompletion:^(NSError *error) {
                    if (error == nil &&  attachment.previewImage.size.height != 0) {
                        self.artwork.image = attachment.previewImage;
                    } else {
                        self.artwork.image = attachment.previewIcon;
                    }
                }];
            } else if (attachment.previewImage.size.height == 0) {
                self.artwork.image = attachment.previewIcon;
            }
        } else {
            self.artwork.image = attachment.previewIcon;
        }
        if (attachment.fileUnavailable) {
            [self strikeThroughTitle];
        }
    } else {
        self.titleLabel.text = @"";
        self.subtitleLabel.text = @"";
        self.artwork.image = nil;
    }

    [self updatePlaybackState];
}

- (void) strikeThroughTitle {
    NSString *title = self.titleLabel.text;
    NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
    NSRange range = NSMakeRange(0,title.length);
    [attributedTitle setAttributes:@{ NSStrikethroughStyleAttributeName: @(YES),
                                      NSStrikethroughColorAttributeName: [UIColor redColor] } range:range];

    self.titleLabel.attributedText = attributedTitle;
}


- (void) highlightText:(NSString *)highlightText {
    NSString *title = self.titleLabel.text;

    if (highlightText && title) {
        NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];

        [title enumerateRangesOfString:highlightText options:NSCaseInsensitiveSearch usingBlock:^(NSRange range) {
            [attributedTitle setAttributes:@{ NSForegroundColorAttributeName: [UIColor blackColor] } range:range];
        }];

        self.titleLabel.textColor = [[HXOUI theme] lightTextColor];
        self.titleLabel.attributedText = attributedTitle;
    }
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
