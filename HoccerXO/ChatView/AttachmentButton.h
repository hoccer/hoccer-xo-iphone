//
//  AttachmentButton.h
//  HoccerXO
//
//  Created by David Siegel on 05.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VectorArt;

@interface AttachmentButton : UIControl

@property (nonatomic, strong) VectorArt * icon;
@property (nonatomic, strong) UIImage   * previewImage;

- (void) startSpinning;
- (void) stopSpinning;

@end
