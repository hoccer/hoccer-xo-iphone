//
//  BubbleView.m
//  HoccerXO
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleView.h"

#import <QuartzCore/QuartzCore.h>

#import "AutoheightLabel.h"
#import "AssetStore.h"
#import "HXOMessage.h"
#import "AttachmentViewFactory.h"
#import "AttachmentView.h"

static const double kLeftBubbleCapLeft  = 11.0;
static const double kRightBubbleCapLeft = 4.0;
static const double kBubbleCapTop   = 32.0;
static const double kAttachmentPadding = 10;

@interface BubbleView ()
{
    CGFloat initialLeftPadding;
    CGFloat initialRightPadding;
    CGFloat initialTopPadding;
    CGFloat initialBottomPadding;
}

@property (strong, nonatomic) UIImageView * background;

@property CGRect initialParentCellFrame;
@property CGRect initialFrame;
@property CGRect initialMessageFrame;

@end

@implementation BubbleView

@synthesize attachmentView = _attachmentView;

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {  
        self.bubbleColor = self.backgroundColor;
        self.backgroundColor = [UIColor clearColor];

    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.padding = UIEdgeInsetsMake(self.message.frame.origin.y,
                                    0.0,
                                    self.message.frame.origin.y,
                                    0.0);

    NSString * file = _pointingRight ? @"bubble-right" : @"bubble-left";
    UIImage * bubble = [AssetStore stretchableImageNamed: file withLeftCapWidth: _pointingRight ? kRightBubbleCapLeft : kLeftBubbleCapLeft topCapHeight:kBubbleCapTop];
    self.background = [[UIImageView alloc] initWithImage: bubble];
	//self.background.frame = self.frame;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self insertSubview: self.background atIndex: 0];

    CGRect of = self.message.frame;
    CGFloat d = kLeftBubbleCapLeft - kRightBubbleCapLeft;
    self.message.frame = CGRectMake(_pointingRight ? of.origin.x : of.origin.x + d, of.origin.y, of.size.width - d, of.size.height);
    self.initialMessageFrame = self.message.frame;
    self.initialParentCellFrame = self.superview.frame;
    self.initialFrame = self.frame;
    self.message.backgroundColor = [UIColor colorWithRed:05 green:0 blue:0 alpha:0.5];
    
    NSLog(@"BubbleView %x awakefromNib self.frame=%@ self.suoerview=%x frame %@",
          (int)self,NSStringFromCGRect(self.frame),(int)self.superview,NSStringFromCGRect(self.initialParentCellFrame));

    initialLeftPadding = self.initialFrame.origin.x - self.initialParentCellFrame.origin.x;
    initialRightPadding = self.initialParentCellFrame.origin.x + self.initialParentCellFrame.size.width - (self.initialFrame.origin.x + self.initialFrame.size.width);
    
    initialTopPadding = self.initialFrame.origin.y - self.initialParentCellFrame.origin.y;
    initialBottomPadding = self.initialParentCellFrame.origin.y + self.initialParentCellFrame.size.height - (self.initialFrame.origin.y + self.initialFrame.size.height);
     
    [self bubbleFrameForCellFrame:self.initialParentCellFrame]; // remove, is just for test output
}

- (CGRect) bubbleFrameForCellFrame:(CGRect) theCellFrame {
    
    CGRect bubbleRect = CGRectMake(theCellFrame.origin.x + initialLeftPadding,
                                   theCellFrame.origin.x + initialTopPadding,
                                   theCellFrame.size.width - (initialLeftPadding + initialRightPadding),
                                   theCellFrame.size.height - (initialTopPadding + initialBottomPadding));
    NSLog(@"BubbleView %x bubbleFrameForCellFrame bubbleRect=%@ for theCellFrame=%@",(int)self,NSStringFromCGRect(bubbleRect),NSStringFromCGRect(theCellFrame));
    NSLog(@"Padding left %f right %f top %f bottom %f",initialLeftPadding,initialRightPadding,initialTopPadding,initialBottomPadding);
    return bubbleRect;
}

- (CGFloat) bubbleWidthForCellWidth:(CGFloat)theCellWidth {
    CGFloat bubbleWidth = theCellWidth - (initialLeftPadding + initialRightPadding);
    return bubbleWidth;
}


- (CGFloat) messageWidthForBubbleWidth:(CGFloat)bubbleWidth {
    CGFloat initialLeftMsgPadding = self.initialMessageFrame.origin.x - self.initialFrame.origin.x;
    CGFloat initialRightMsgPadding = self.initialFrame.origin.x + self.initialFrame.size.width
                                - (self.initialMessageFrame.origin.x + self.initialMessageFrame.size.width);
    CGFloat messageWidth = bubbleWidth - (initialLeftMsgPadding + initialRightMsgPadding);
    return messageWidth;
}

- (CGFloat) messageWidthForCellWidth:(CGFloat)cellWidth {
    return [self messageWidthForBubbleWidth:[self bubbleWidthForCellWidth:cellWidth]];
}

- (void) setAttachmentView: (AttachmentView*) view {
    if (_attachmentView != nil) {
        [_attachmentView removeFromSuperview];
    }
    _attachmentView = view;
    if (_attachmentView != nil) {
        // XXX
        _attachmentView.contentMode = UIViewContentModeScaleAspectFit;
        //CGFloat aspect = ((UIImageView*)_attachmentView).frame.size.width / ((UIImageView*)_attachmentView).frame.size.height;
        // CGFloat aspect = _attachmentView.frame.size.width / _attachmentView.frame.size.height;
        CGFloat aspect = view.aspect;
        _attachmentView.frame = [self calcAttachmentViewFrameForAspect:aspect];
        [self addSubview: view];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self setNeedsLayout];
}

- (CGRect) calcAttachmentViewFrameForAspect:(float)aspectRatio {
        return CGRectMake(self.message.frame.origin.x, self.message.frame.origin.y + self.message.frame.size.height + kAttachmentPadding,
                                           self.message.frame.size.width, self.message.frame.size.width / aspectRatio);
}

- (CGSize) sizeThatFits:(CGSize)size {
    // TODO: get rit of awkward + 5
    CGFloat height = self.message.frame.size.height + self.padding.top + self.padding.bottom; // + 5;
    if (self.attachmentView != nil) {
        // height += kAttachmentPadding + self.attachmentView.frame.size.height;
        height += kAttachmentPadding + self.message.frame.size.width / self.attachmentView.aspect;
    }
    NSLog(@"BubbleView %x sizeThatFits before %@ after %@",(int)self,NSStringFromCGSize(size), NSStringFromCGSize(CGSizeMake(self.frame.size.width, height)));

    return CGSizeMake(self.frame.size.width, height);
}

- (void) layoutSubviews {
    // NSLog(@"BubbleView %x:layoutSubviews before self.bounds=%@",(__bridge void*)self,NSStringFromCGRect(self.bounds));
    NSLog(@"BubbleView %x:layoutSubviews before self.frame=%@",(int)self,NSStringFromCGRect(self.frame));
    NSLog(@"BubbleView %x:layoutSubviews before message.frame=%@",(int)self,NSStringFromCGRect(self.message.frame));
    CGRect messageFrame = self.message.frame;
    messageFrame.size.width = [self messageWidthForCellWidth: self.superview.frame.size.width];
    messageFrame.size.height = [self.message calculateSize: self.message.text].height;
    self.message.frame = messageFrame;
    if (self.attachmentView != nil) {
        _attachmentView.frame = [self calcAttachmentViewFrameForAspect:_attachmentView.aspect];
    }
    [super layoutSubviews];
    [self sizeToFit];
    self.background.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
    //NSLog(@"BubbleView %x:layoutSubviews after self.bounds=%@",(__bridge void*)self,NSStringFromCGRect(self.bounds));
    NSLog(@"BubbleView %x:layoutSubviews after self.frame=%@",(int)self,NSStringFromCGRect(self.frame));
    NSLog(@"BubbleView %x:layoutSubviews before message.frame=%@",(int)self,NSStringFromCGRect(self.message.frame));
}

- (CGFloat) heightForMessage: (HXOMessage*) message {
    CGFloat height = self.padding.top + [self.message calculateSize: message.body].height + self.padding.bottom;
    if (message.attachment != nil) {
        height += kAttachmentPadding + [AttachmentViewFactory heightOfAttachmentView: message.attachment withViewOfWidth: self.message.frame.size.width];
    }
    return height;
}

- (void) setState:(BubbleState)state {
    _state = state;
    NSString * stateString = nil;
    switch (state) {
        case BubbleStateInTransit:
            stateString = @"-in_transit";
            break;
        case BubbleStateDelivered:
            stateString = @"";
            break;
        case BubbleStateFailed:
            stateString = @"-failed";
            break;
    }
    NSString * assetName = [NSString stringWithFormat: @"bubble-%@%@", _pointingRight ? @"right" : @"left", stateString];
    self.background.image =[AssetStore stretchableImageNamed: assetName withLeftCapWidth: _pointingRight ? kRightBubbleCapLeft : kLeftBubbleCapLeft topCapHeight:kBubbleCapTop];
}

@end
