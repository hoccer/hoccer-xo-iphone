//
//  AttachmentSection.h
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageSection.h"

@interface AttachmentSection : MessageSection

@property (nonatomic,readonly) UILabel * subtitle;
@property (nonatomic,readonly) UIProgressView * progressView;

@end
