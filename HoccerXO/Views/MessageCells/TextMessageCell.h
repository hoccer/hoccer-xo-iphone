//
//  TextMessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 10.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@class TextSection;
@class HXOLinkyLabel;

@interface TextMessageCell : MessageCell

@property (nonatomic,readonly) TextSection * textSection;

@end
