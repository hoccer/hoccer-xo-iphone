//
//  ChatTableViewCell.m
//  ChatSpike
//
//  Created by David Siegel on 05.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatCell.h"

@implementation ChatCell

@synthesize label;

+ (NSString *)reuseIdentifier
{
    return NSStringFromClass(self);
}

- (NSString *)reuseIdentifier
{
    return [[self class] reuseIdentifier];
}

+ (ChatCell *)cell
{
    return [[[NSBundle mainBundle] loadNibNamed:[self reuseIdentifier] owner:self options:nil] objectAtIndex:0];
}

+ (float) heightForText: (NSString*) text {
    ChatCell * cell = [ChatCell prototype];
    CGSize maxSize = {cell.label.frame.size.width, 10000};
    return 10 + [text sizeWithFont: cell.label.font constrainedToSize: maxSize lineBreakMode: NSLineBreakByWordWrapping].height + 10;
}

+ (ChatCell*) prototype {
    static ChatCell * p;
    if ( ! p) p = [ChatCell cell];
    return p;
}
@end
