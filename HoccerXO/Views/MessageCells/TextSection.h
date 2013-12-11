//
//  TextSection.h
//  HoccerXO
//
//  Created by David Siegel on 11.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageSection.h"

@class HXOLinkyLabel;

@interface TextSection : MessageSection

@property (nonatomic,readonly) HXOLinkyLabel * label;

@end
