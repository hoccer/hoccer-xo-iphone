//
//  AttachmentView.m
//  HoccerXO
//
//  Created by Pavel on 15.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentView.h"
#import "ChatTableCells.h"
#import "HXOMessage.h"
#import "HXOUserDefaults.h"
#import "BubbleView.h"

#import "UIButton+GlossyRounded.h"


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
        [progressView setProgress: theProgress animated:YES];
    }
}

- (void) transferStarted {
    // NSLog(@"transferStarted, cell = %@, attachment = %@", self.attachment, self.cell);
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

    CGRect AVframe = [theCell.bubble calcAttachmentViewFrameForAspect:theAttachment.aspectRatio];
    self.frame = CGRectMake(0,0,AVframe.size.width, AVframe.size.height);
    CGRect frame = self.frame;
    
    NSLog(@"configureViewForAttachment: frame = %@", NSStringFromCGRect(frame));
    NSLog(@"configureViewForAttachment: bounds = %@", NSStringFromCGRect(self.bounds));
    NSLog(@"configureViewForAttachment: AVframe = %@", NSStringFromCGRect(AVframe));
    //NSLog(@"configureViewForAttachment: cell.frame = %@", NSStringFromCGRect(theCell.frame));
    
    AttachmentState attachmentState = theAttachment.state;
    BOOL isOutgoing = [self.attachment.message.isOutgoing isEqualToNumber: @YES];
    
    if (self.imageView == nil) {
        self.imageView = [[UIImageView alloc] init];
        
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
        self.imageView.frame = frame;        
    }
        
    NSLog(@"configureViewForAttachment1: progressView.frame = %@", NSStringFromCGRect(progressView.frame));
    if (self.progressView == nil) {
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.frame = self.frame;
        //[self.progressView setFrame:CGRectMake(AVframe.origin.x, AVframe.origin.y, AVframe.size.width, 10)];
        //self.progressView = [[UIProgressView alloc] init];
        self.progressView.hidden = NO;
        self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;//|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.progressView.alpha = 1.0;
        self.progressView.contentMode = UIViewContentModeBottom;
        NSLog(@"configureViewForAttachment2: progressView.frame = %@", NSStringFromCGRect(progressView.frame));
        [self addSubview: self.progressView];
        NSLog(@"configureViewForAttachment3: progressView.frame = %@", NSStringFromCGRect(progressView.frame));
    } else {
        //[self.progressView setFrame:CGRectMake(AVframe.origin.x, AVframe.origin.y, AVframe.size.width, 10)];
        // [self.progressView setFrame:CGRectMake(0, 10, 300, 10)];
        NSLog(@"configureViewForAttachment4: progressView.frame = %@", NSStringFromCGRect(progressView.frame));
        self.progressView.frame = self.frame;
        NSLog(@"configureViewForAttachment5: progressView.frame = %@", NSStringFromCGRect(progressView.frame));
    }
    NSLog(@"configureViewForAttachment6: self.frame = %@", NSStringFromCGRect(self.frame));
    NSLog(@"configureViewForAttachment7: self.bounds = %@", NSStringFromCGRect(self.bounds));

    if (attachmentState == kAttachmentTransfering || attachmentState == kAttachmentTransferPaused) {
        [self.progressView setProgress: [attachment.transferSize doubleValue] / [attachment.contentSize doubleValue]];
        self.progressView.hidden = NO;
        // TODO: cancel transfer button
    } else {
        self.progressView.hidden = YES;
    }
    if (attachmentState == kAttachmentTransferOnHold)
    {
        if (self.loadButton == nil) {
            //self.loadButton = [[UIButton alloc] initWithFrame: self.bounds];
            self.loadButton = [[UIButton alloc] initWithFrame:self.frame];
            self.loadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            [self.loadButton setBackgroundColor: [UIColor colorWithRed:0 green:0 blue:0.8 alpha:1]];
            [self.loadButton makeRoundAndGlossy];
            self.loadButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.loadButton.titleLabel.textAlignment = NSTextAlignmentCenter;
            [self.loadButton addTarget:attachment action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:self.loadButton];
        } else {
            [self.loadButton undoRoundAndGlossy];
            self.loadButton.frame = self.frame;
            [self.loadButton makeRoundAndGlossy];
        }
        if ([self.attachment.message.isOutgoing isEqualToNumber: @YES])  {
            // upload not yet started, present upload button
            NSString * myTitle = [NSString localizedStringWithFormat:NSLocalizedString(@"Upload %@\n%1.2f MB",nil),
                                  NSLocalizedString(attachment.mediaType, nil),
                                  [attachment.contentSize doubleValue]/1024/1024];
            [self.loadButton setTitle:myTitle forState:UIControlStateNormal];
        } else {
            // download not yet started, present download button
            NSString * myTitle = [NSString localizedStringWithFormat:NSLocalizedString(@"Download %@\n%1.2f MB",nil),
                                  NSLocalizedString(attachment.mediaType, nil),
                                  [attachment.contentSize doubleValue]/1024/1024];
            [self.loadButton setTitle:myTitle forState:UIControlStateNormal];
        }
                
    } else {
        if (self.loadButton != nil) {
            [self.loadButton removeFromSuperview];
            self.loadButton = nil;
        }
        
        if (attachmentState == kAttachmentTransfered ||
            (isOutgoing &&
             (attachmentState == kAttachmentTransferPaused ||
              attachmentState == kAttachmentTransfering)))
        {
            // normal view with image and play/open button
            
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
            } else {
                self.openButton.frame = self.frame;
            }
            
            if (self.imageView.image == nil) {
                if (self.attachment.previewImage == nil) {
                    [self.attachment loadPreviewImageIntoCacheWithCompletion:^(NSError * error) {
                        if (error == nil) {
                            self.imageView.image = self.attachment.previewImage;
                        } else {
                            NSLog(@"ERROR: viewForAttachment: failed to load attachment image, error=%@",error);
                        }
                    }];
                } else {
                    self.imageView.image = self.attachment.previewImage;
                }
            }
            if (attachmentState == kAttachmentTransfering) {
                self.imageView.alpha = 1.0;
            } else {
                self.imageView.alpha = 1.0;
            }
        } 
    }
}
    
@end
