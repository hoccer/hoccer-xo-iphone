//
//  HXOActionSheet.h
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface HXOSheetView : UIView
{
    UIView *         _coverView;
    UIView *         _actionView;
}

@property (nonatomic,copy) NSString * title;

- (id) initWithTitle: (NSString*) title;

- (void)showInView:(UIView *)view;

@end
