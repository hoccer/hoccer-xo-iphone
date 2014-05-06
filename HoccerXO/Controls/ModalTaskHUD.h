//
//  ModalTaskHUD.h
//  HoccerXO
//
//  Created by David Siegel on 06.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ModalTaskHUD : UIView

@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) UIColor  * dimColor;


- (void) show;
- (void) dismiss;

+ (id) modalTaskHUDWithTitle: (NSString*) title;

@end
