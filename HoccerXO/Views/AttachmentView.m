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
        progressView.hidden = NO;
        [progressView setProgress: theProgress animated:YES];
    }
}

- (void) transferStarted {
    NSLog(@"transferStarted, cell = %@, attachment = %@", self.attachment, self.cell);
    if (self.attachment != nil && self.cell != nil) {
        progressView.hidden = NO;
        [self.cell setNeedsLayout];
    }
}

- (void) transferFinished {
    NSLog(@"transferFinished, cell = %@, attachment = %@", self.attachment, self.cell);
    if (self.attachment != nil && self.cell != nil) {
        // self.attachment.progressIndicatorDelegate = nil;
        progressView.hidden = YES;
        [self.cell setNeedsLayout];
    }
}

// TODO: call when transfer is scheduled
- (void) transferScheduled {
    NSLog(@"transferScheduled, cell = %@, attachment = %@", self.attachment, self.cell);
    if (self.attachment != nil && self.cell != nil) {
        [self.cell setNeedsLayout];
    }
}

- (void) configureViewForAttachment: (Attachment*) theAttachment inCell:(MessageCell*) theCell {

    // remove potentially leftover targets
    [self.openButton removeTarget:self.cell action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.loadButton removeTarget:self.attachment action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];

    self.attachment = theAttachment;
    self.cell = theCell;
    self.aspect = theAttachment.aspectRatio;
    self.userInteractionEnabled = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    // self.clipsToBounds = YES;
    
    CGRect AVframe = [theCell.bubble calcAttachmentViewFrameForAspect:theAttachment.aspectRatio];
    self.frame = CGRectMake(0,0,AVframe.size.width, AVframe.size.height);
    CGRect frame = self.frame;
    
    NSLog(@"configureViewForAttachment BubbleView %x attachment %x",(int)(__bridge void*)self.cell.bubble, (int)(__bridge void*)theAttachment);
    NSLog(@"configureViewForAttachment: frame = %@", NSStringFromCGRect(frame));
    NSLog(@"configureViewForAttachment: bounds = %@", NSStringFromCGRect(self.bounds));
    NSLog(@"configureViewForAttachment: AVframe = %@", NSStringFromCGRect(AVframe));
    NSLog(@"configureViewForAttachment: superview class= %@", [self.superview class]);
    NSLog(@"configureViewForAttachment: superview.frame = %@", NSStringFromCGRect(self.superview.frame));
    NSLog(@"configureViewForAttachment: superview.bounds = %@", NSStringFromCGRect(self.superview.bounds));
    NSLog(@"configureViewForAttachment: cell.frame = %@", NSStringFromCGRect(theCell.frame));
    
    AttachmentState attachmentState = theAttachment.state;
    BOOL isOutgoing = [self.attachment.message.isOutgoing isEqualToNumber: @YES];
    
    if (self.imageView == nil) {
        self.imageView = [[UIImageView alloc] init];
        
        self.imageView.frame = frame;
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        [self addSubview:imageView];
        self.frame = frame;
        NSLog(@"configureViewForAttachment: new imageview");
    } else {
        self.imageView.frame = frame;
        self.imageView.image = nil;
        NSLog(@"configureViewForAttachment: reuse imageview");
    }
        
    UIColor * buttonColor;
    if (attachmentState == kAttachmentTransfersExhausted) {
        buttonColor = [UIColor colorWithRed:0.8 green:0 blue:0 alpha:1];
    } else {
        buttonColor = [UIColor colorWithRed:0 green:0 blue:0.8 alpha:1];
    }
    
    // create loadbutton
    if (self.loadButton == nil) {
        //self.loadButton = [[UIButton alloc] initWithFrame: self.bounds];
        self.loadButton = [[UIButton alloc] initWithFrame:self.frame];
        self.loadButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self.loadButton setBackgroundColor: buttonColor];
        [self.loadButton makeRoundAndGlossy];
        self.loadButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.loadButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:self.loadButton];
        NSLog(@"configureViewForAttachment: new loadbutton");
    } else {
        // renew gloss for possibly changed dimensions
        [self.loadButton undoRoundAndGlossy];
        [self.loadButton setBackgroundColor: buttonColor];
        self.loadButton.frame = self.frame;
        [self.loadButton makeRoundAndGlossy];
        NSLog(@"configureViewForAttachment: may reuse loadbutton");
    }
    
    // create openButton
    if (self.openButton == nil) {
        // NSLog(@"configureViewForAttachment: (buttoninit) frame = %@", NSStringFromCGRect(self.bounds));
        self.openButton = [[UIButton alloc] initWithFrame: self.bounds];
        [self addSubview:self.openButton];
        self.openButton.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;        
        NSLog(@"configureViewForAttachment: new openbutton");
    } else {
        self.openButton.frame = self.frame;
        NSLog(@"configureViewForAttachment: reuse openbutton");
    }
    
    if (self.nameLabel == nil) {
        self.nameLabel = [[UILabel alloc] init];
        self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
        self.nameLabel.textColor = [UIColor blackColor];
        self.nameLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        self.nameLabel.textAlignment = NSTextAlignmentCenter;
        self.nameLabel.font = [UIFont italicSystemFontOfSize:10];
        [self addSubview:self.nameLabel];
    }
    self.nameLabel.hidden = YES;
    
    if (attachmentState == kAttachmentTransferOnHold ||
        attachmentState == kAttachmentTransfersExhausted ||
        attachmentState == kAttachmentUploadIncomplete ||
        attachmentState == kAttachmentDownloadIncomplete)
    {
        self.loadButton.hidden = NO;
        self.openButton.hidden = YES;
                
        [self.loadButton setTitle:[self getButtonTitle] forState:UIControlStateNormal];
        [self.loadButton addTarget:attachment action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
        NSLog(@"configureViewForAttachment: use loadbutton, hide openbutton");
        
    } else {
        self.loadButton.hidden = YES;
        self.openButton.hidden = NO;
        
        // set proper button image
        if ( [attachment.mediaType isEqualToString:@"video"]) {
            [self.openButton setImage: [UIImage imageNamed:@"button-video"] forState:UIControlStateNormal];
        } else if ([attachment.mediaType isEqualToString:@"audio"]) {
            [self.openButton setImage: [UIImage imageNamed:@"button-audio"] forState:UIControlStateNormal];
        } else {
            [self.openButton setImage:nil forState:UIControlStateNormal];
        }
        
        [self.openButton addTarget:cell action:@selector(pressedButton:) forControlEvents:UIControlEventTouchUpInside];
        NSLog(@"configureViewForAttachment: use openbutton, hide loadbutton");
    }
    
    // now set imageView Image if we can
    if (attachmentState == kAttachmentTransfered ||
        (isOutgoing &&
         (attachmentState == kAttachmentTransferPaused ||
          attachmentState == kAttachmentTransfering)))
    {
        if ([attachment.mediaType isEqualToString:@"audio"]) {
            self.nameLabel.text = theAttachment.humanReadableFileName;
            CGRect myFrame = frame;
            myFrame.size.height = frame.size.height * 0.1;
            myFrame.origin.y = frame.size.height * 0.8;
            self.nameLabel.frame = myFrame;
            self.nameLabel.hidden = NO;
        }
        if (self.attachment.previewImage == nil) {
            NSLog(@"configureViewForAttachment: load image");
            [self.attachment loadPreviewImageIntoCacheWithCompletion:^(NSError * error) {
                if (error == nil) {
                    self.imageView.image = self.attachment.previewImage;
                    [cell setNeedsLayout];
                } else {
                    NSLog(@"ERROR: viewForAttachment: failed to load attachment image, error=%@",error);
                }
            }];
        } else {
            NSLog(@"configureViewForAttachment: get image");
            self.imageView.image = self.attachment.previewImage;
        }
    }
    
    // we can play with alpha here
    if (attachmentState == kAttachmentTransfering) {
        self.imageView.alpha = 0.5;
    } else {
        self.imageView.alpha = 1.0;
    }

    // and finally the progress view
    if (self.progressView == nil) {
        self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        self.progressView.frame = self.frame;
        [self.progressView setFrame:CGRectMake(0, 0, AVframe.size.width, 9)];
        self.progressView.hidden = NO;
        self.progressView.alpha = 1.0;
        [self addSubview: self.progressView];
        NSLog(@"configureViewForAttachment: new progress");
    } else {
        progressView.frame = self.frame;
        NSLog(@"configureViewForAttachment: reuse progress");
    }

    if (attachmentState == kAttachmentTransfering ||
        attachmentState == kAttachmentTransferPaused ||
        attachmentState == kAttachmentTransferScheduled)
    {
        [self.progressView setProgress: [attachment.transferSize doubleValue] / [attachment.contentSize doubleValue]];
        self.progressView.hidden = NO;
        NSLog(@"configureViewForAttachment: use progress");
        
        self.nameLabel.text = [self getTransferedTitle];
        self.nameLabel.hidden = NO;

        // TODO: cancel transfer button
    } else {
        self.progressView.hidden = YES;
        NSLog(@"configureViewForAttachment: no progress");
    }
}

- (NSString *) getTransferedTitle {
    if (self.attachment.state == kAttachmentTransferScheduled) {
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Will Retry transfer %@",nil),[self.attachment.transferRetryTimer fireDate]];
    }
    if ([self.attachment.message.isOutgoing isEqualToNumber: @YES])  {
        // upload not yet started, present upload button
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Uploaded %1.3f of %1.3f MB",nil),
                              [attachment.transferSize doubleValue]/1024/1024,
                              [attachment.contentSize doubleValue]/1024/1024];
    } else {
        // download not yet started, present download button
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Downloaded %1.3f of %1.3f MB",nil),
                              [attachment.transferSize doubleValue]/1024/1024,
                              [attachment.contentSize doubleValue]/1024/1024];
    }
}

- (NSString *) getButtonTitle {
    if ([self.attachment.message.isOutgoing isEqualToNumber: @YES])  {
        // upload not yet started, present upload button
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Upload %@\n%1.2f MB",nil),
                NSLocalizedString(attachment.mediaType, nil),
                [attachment.contentSize doubleValue]/1024/1024];
    } else {
        // download not yet started, present download button
        return [NSString localizedStringWithFormat:NSLocalizedString(@"Download %@\n%1.2f MB",nil),
                NSLocalizedString(attachment.mediaType, nil),
                [attachment.contentSize doubleValue]/1024/1024];
    }
}

/*
- (void) layoutSubviews {
    CGRect AVframe = [self.cell.bubble calcAttachmentViewFrameForAspect:self.aspect];
    // self.frame = CGRectMake(0,0,AVframe.size.width, AVframe.size.height);
    CGRect frame = AVframe;
 
    self.imageView.frame = frame;
    self.openButton.frame = frame;
    self.loadButton.frame = frame;
    self.progressView.frame = CGRectMake(0, 0, AVframe.size.width, 9);

    //[super layoutSubviews];
    //[self sizeToFit];
}
*/

@end
