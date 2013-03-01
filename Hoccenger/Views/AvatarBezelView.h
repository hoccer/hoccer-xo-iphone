//
//  AvatarView.h
//  Hoccenger
//
//  Created by David Siegel on 01.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AvatarBezelView : UIView

@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) UIImage *image;

- (void) awakeFromNib;

@end
