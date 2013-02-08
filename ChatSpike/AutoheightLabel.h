//
//  AutosizeLabel.h
//  ChatSpike
//
//  Created by David Siegel on 06.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AutoheightLabel : UILabel
{
    double minHeight;
}

@property (nonatomic) double minHeight;

- (CGSize) calculateSize: (NSString*) text;

@end
