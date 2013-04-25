//
//  AttachmentView.m
//  HoccerTalk
//
//  Created by Pavel on 15.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentView.h"
#import "ChatTableCells.h"
#import "TalkMessage.h"
#import "HXOUserDefaults.h"

@implementation AttachmentView

@synthesize imageView;
@synthesize progressView;
@synthesize openButton;
@synthesize loadButton;
@synthesize attachment;
@synthesize cell;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void) showTransferProgress:(float) theProgress {
    // NSLog(@"showTransferProgress %f", theProgress);
    if (progressView != nil) {
        // NSLog(@"showTransferProgress, really %f", theProgress);
        self.progressView.hidden = NO;
        [progressView setProgress: theProgress];
    }
}

- (void) transferStarted {
    // NSLog(@"transferFinished, cell = %@, attachment = %@", self.attachment, self.cell);
    if (self.attachment != nil && self.cell != nil) {
        [self configureViewForAttachment: self.attachment inCell: self.cell];
        self.progressView.hidden = NO;
    }
}

- (void) transferFinished {
    // NSLog(@"transferFinished, cell = %@, attachment = %@", self.attachment, self.cell);
    if (self.attachment != nil && self.cell != nil) {
        [self configureViewForAttachment: self.attachment inCell: self.cell];
        self.attachment.progressIndicatorDelegate = nil;
        self.progressView.hidden = YES;
    }
}

- (void) configureViewForAttachment: (Attachment*) theAttachment inCell:(MessageCell*) theCell {
    self.attachment = theAttachment;
    self.cell = theCell;
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

    CGRect frame = self.frame;
    
    // NSLog(@"configureViewForAttachment: frame = %@", NSStringFromCGRect(frame));
    
    if (self.imageView == nil) {
        self.imageView = [[UIImageView alloc] init];
        // preset frame to correct aspect ratio before actual image is loaded
        frame.size.width = attachment.aspectRatio;
        frame.size.height = 1;
        self.imageView.frame = frame;
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        [self addSubview:imageView];
        self.frame = frame;
        // NSLog(@"configureViewForAttachment: (postInit) frame = %@", NSStringFromCGRect(frame));
        if ([attachment.mediaType isEqualToString:@"audio"]) {
            UILabel * myNameLabel = [[UILabel alloc] init];
            myNameLabel.text = theAttachment.humanReadableFileName;
            myNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
            myNameLabel.textColor = [UIColor blackColor];
            myNameLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
            myNameLabel.textAlignment = NSTextAlignmentCenter;
            myNameLabel.font = [UIFont italicSystemFontOfSize:10];
            CGRect myFrame = frame;
            myFrame.size.height = frame.size.height * 0.1;
            myFrame.origin.y = frame.size.height * 0.8;
            myNameLabel.frame = myFrame;
            [self addSubview:myNameLabel];
        }
        // NSLog(@"configureViewForAttachment: (postInit) frame = %@", NSStringFromCGRect(frame));
    } else {
        frame.size.height = frame.size.width / attachment.aspectRatio;
        self.frame = frame;
    }
    
    if (self.progressView == nil) {
        // transfer ongoing, present progress bar
        self.progressView = [[UIProgressView alloc] initWithFrame: self.frame];
        self.progressView.hidden = NO;
        self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview: self.progressView];
    }

    if (attachment.transferConnection != nil) {
        [self.progressView setProgress: [attachment.transferSize doubleValue] / [attachment.contentSize doubleValue]];
        self.progressView.hidden = NO;
        
        // TODO: cancel transfer button
        
    } else {
        // transfer ready or not yet started
        if ([attachment.contentSize longLongValue] > [attachment.transferSize longLongValue]) {
            // transfer incomplete and not active
            
            BOOL isOutgoing = [self.attachment.message.isOutgoing isEqualToNumber: @YES];
            long long outgoingLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHTAutoUploadLimit] longLongValue];
            long long incomingLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHTAutoDownloadLimit] longLongValue];
            
            if (((isOutgoing && [self.attachment.contentSize longLongValue] > outgoingLimit) ||
                (!isOutgoing && [self.attachment.contentSize longLongValue] > incomingLimit)) &&
                ([self.attachment.transferSize longLongValue] == 0))
            {
                self.progressView.hidden = NO;
                if (self.loadButton == nil) {
                     self.loadButton = [[UIButton alloc] initWithFrame: self.bounds];
                    [self addSubview:self.loadButton];
                }
                if ([self.attachment.message.isOutgoing isEqualToNumber: @YES])  {
                    // upload not yet started, present upload button
                    NSString * myTitle = [NSString stringWithFormat:@"Upload %1.3f MByte",[attachment.contentSize doubleValue]/1024/1024];
                    [self.loadButton setTitle:myTitle forState:UIControlStateNormal];
                } else {
                    // download not yet started, present download button
                    NSString * myTitle = [NSString stringWithFormat:@"Download %1.3f MByte",[attachment.contentSize doubleValue]/1024/1024];
                    [self.loadButton setTitle:myTitle forState:UIControlStateNormal];
                }
                [self.loadButton addTarget:attachment action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
                
                self.loadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
                
                //UIImage *sendButtonBackground = [UIImage imageNamed:@"chatbar_btn-send"];
                // [self.loadButton setBackgroundImage: sendButtonBackground forState: UIControlStateNormal];
                [self.loadButton setBackgroundColor: [UIColor blueColor]];
                self.loadButton.titleLabel.shadowOffset  = CGSizeMake(0.0, -1.0);
                [self.loadButton setTitleShadowColor:[UIColor colorWithWhite: 0 alpha: 0.4] forState:UIControlStateNormal];
            }
            return;
        } else {
            // normal view with image and play/open button
            self.progressView.hidden = YES;
            if (self.loadButton != nil) {
                [self.loadButton removeFromSuperview];
                self.loadButton = nil;
            }
            if (self.openButton == nil) {
                // NSLog(@"configureViewForAttachment: (buttoninit) frame = %@", NSStringFromCGRect(self.bounds));
                self.openButton = [[UIButton alloc] initWithFrame: self.bounds];
                [self addSubview:self.openButton];
                self.openButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
                
                if ( [attachment.mediaType isEqualToString:@"video"]) {
                    [self.openButton setImage: [UIImage imageNamed:@"button-video"] forState:UIControlStateNormal];
                }
                if ([attachment.mediaType isEqualToString:@"audio"]) {
                    [self.openButton setImage: [UIImage imageNamed:@"button-audio"] forState:UIControlStateNormal];
                }
                
                [self.openButton addTarget:cell action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];                
            }
            
            if (self.imageView.image == nil) {
                if (self.attachment.previewImage == nil) {
                    [self.attachment loadPreviewImageIntoCacheWithCompletion:^(NSError * error) {
                        if (error == nil) {
                            self.imageView.image = self.attachment.previewImage;
                        } else {
                            NSLog(@"viewForAttachment: failed to load attachment image, error=%@",error);
                        }
                    }];
                } else {
                    self.imageView.image = self.attachment.previewImage;
                }
            }
        }
    }
}


@end
