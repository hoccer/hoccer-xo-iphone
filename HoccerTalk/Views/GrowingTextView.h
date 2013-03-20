//
//  AttachmentViewFactory.h
//  HoccerTalk
//
//  Created by David Siegel on 20.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//


// Based on http://www.hanspinckaers.com/multi-line-uitextview-similar-to-sms

#import <UIKit/UIKit.h>

@class GrowingTextView;

@protocol GrowingTextViewDelegate

@optional
- (void)growingTextView:(GrowingTextView *)growingTextView willChangeHeight:(float)height;
- (void)growingTextView:(GrowingTextView *)growingTextView didChangeHeight:(float)height;
@end

@interface GrowingTextView : UITextView <UITextViewDelegate>

@property CGFloat maxHeight;
@property BOOL animateHeightChange;
@property (assign) UIEdgeInsets padding;
@property(nonatomic,unsafe_unretained) id<UITextViewDelegate,GrowingTextViewDelegate> delegate;

@end
