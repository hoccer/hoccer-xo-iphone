//
//  ImageAttachmentSection.h
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AttachmentSection.h"

@interface ImageAttachmentSection : AttachmentSection

@property (nonatomic,strong) UIImage * image;
@property (nonatomic,assign) CGFloat   imageAspect;
@property (nonatomic,assign) BOOL      showPlayButton;

@end
