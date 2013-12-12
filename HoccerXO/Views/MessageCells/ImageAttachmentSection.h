//
//  ImageAttachmentSection.h
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageSection.h"

@interface ImageAttachmentSection : MessageSection

@property (nonatomic,strong) UIImage * image;
@property (nonatomic,assign) CGFloat   imageAspect;

@end
