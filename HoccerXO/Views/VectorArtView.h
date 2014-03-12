//
//  VectorArtView.h
//  HoccerXO
//
//  Created by David Siegel on 12.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VectorArtView : UIView

@property (nonatomic,strong) CAShapeLayer * shape;

+ (id) disclosureArrow;

@end
