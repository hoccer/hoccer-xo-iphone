//
//  HXOActionSheet.h
//  HoccerXO
//
//  Created by David Siegel on 07.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HXOActionSheet;

@protocol HXOActionSheetDelegate <NSObject>

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;

@end

@interface HXOActionSheet : UIView
{
    NSMutableArray * _buttonTitles;
    UIView *         _coverView;
    UIView *         _actionView;
    NSUInteger       _initialOrientation;
}

@property (nonatomic,assign) id<HXOActionSheetDelegate> delegate;
@property (nonatomic,copy) NSString * title;

@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic) NSInteger destructiveButtonIndex;
@property (nonatomic,readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic,readonly) NSInteger numberOfButtons;

- (id)initWithTitle:(NSString *)title delegate:(id <HXOActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;

- (NSInteger) addButtonWithTitle: (NSString*) title;
- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex;
- (void)showInView:(UIView *)view;

@end
