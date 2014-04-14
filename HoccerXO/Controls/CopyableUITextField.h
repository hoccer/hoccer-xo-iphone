//
//  CopyableUITextField.h
//  HoccerXO
//
//  Created by Pavel on 10.09.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//
// based on http://www.bartlettpublishing.com/site/bartpub/blog/3/entry/371


#import <UIKit/UIKit.h>

@interface CopyableUITextFieldResponderView : UIView
@property (strong, nonatomic) UIGestureRecognizer *contextGestureRecognizer;
@end

@interface CopyableUITextField : UITextField
@property (strong, nonatomic) CopyableUITextFieldResponderView *contextGestureRecognizerViewForDisabled;
@end

