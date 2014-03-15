//
//  ChatBar.h
//  HoccerXO
//
//  Created by David Siegel on 30.10.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChatBar : UIToolbar <UITextViewDelegate>

@property (nonatomic,readonly) UIButton   * attachmentButton;
@property (nonatomic,readonly) UITextView * messageField;
@property (nonatomic,readonly) UIButton   * sendButton;

@end
