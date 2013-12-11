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
{
    TextSection * _textSection;
}

@property (nonatomic,readonly) HXOLinkyLabel * label;

@end
