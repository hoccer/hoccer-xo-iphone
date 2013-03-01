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
}

@property (nonatomic) double minHeight;
@property (nonatomic) double arrowWidth;
@property (nonatomic) double arrowHeight;
@property (nonatomic) double arrowHCenter;
@property (nonatomic) BOOL arrowLeft;

- (CGSize) calculateSize: (NSString*) text;

@end
