//
//  HXOActionSheet.h
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef enum HXOSheetStyles {
    HXOSheetStyleAutomatic        = -1,
    HXOSheetStyleDefault          = UIBarStyleDefault,
    HXOSheetStyleBlackOpaque      = UIBarStyleBlackOpaque,
    HXOSheetStyleBlackTranslucent = UIBarStyleBlackTranslucent
} HXOSheetStyle;


@interface HXOSheetView : UIView
{
    UIView * _coverView;
    UIView * _actionView;
    UILabel* _titleLabel;
}

@property (nonatomic,strong) NSString *    title;
@property (nonatomic,assign) HXOSheetStyle sheetStyle UI_APPEARANCE_SELECTOR;

- (id) initWithTitle: (NSString*) title;

- (void)showInView:(UIView *)view;

- (CGFloat) layoutControls: (UIView*) container maxFrame: (CGRect) maxFrame;
- (CGSize)  controlSize: (CGSize) size;

- (void) dismissAnimated: (BOOL) animated completion: (void(^)()) completion;

- (void) didFinishInAnimation;

@end
