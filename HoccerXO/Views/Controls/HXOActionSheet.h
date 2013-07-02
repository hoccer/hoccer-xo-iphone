//
//  HXOActionSheet.h
//  HoccerToolKit
//
//  Created by David Siegel on 26.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOSheetView.h"

@class HXOActionSheet;

#define USE_HXO_ACTION_SHEET

#ifdef USE_HXO_ACTION_SHEET
typedef HXOActionSheet ActionSheet;
#   define ActionSheetDelegate HXOActionSheetDelegate
#else
typedef UIActionSheet ActionSheet;
#   define ActionSheetDelegate UIActionSheetDelegate
#endif


@protocol HXOActionSheetDelegate <NSObject>
- (void)actionSheet:(HXOActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;

@end

@interface HXOActionSheet : HXOSheetView <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray * _buttonTitles;
    NSMutableArray * _buttonViews;
    UITableView    * _buttonTable;
    UIButton       * _tableModeCancelButton;
    UIButton       * _tableModelDestructiveButton;
}

@property (nonatomic,assign) id<HXOActionSheetDelegate> delegate;

@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic) NSInteger destructiveButtonIndex;
@property (nonatomic,readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic,readonly) NSInteger numberOfButtons;

@property (nonatomic,strong) UIImage * destructiveButtonBackgroundImage UI_APPEARANCE_SELECTOR;
@property (nonatomic,strong) UIImage * cancelButtonBackgroundImage      UI_APPEARANCE_SELECTOR;
@property (nonatomic,strong) UIImage * otherButtonBackgroundImage       UI_APPEARANCE_SELECTOR;

@property (nonatomic,strong) Class otherButtonCellClass;
@property (nonatomic,assign) HXOSheetStyle actionSheetStyle; // compatibility property.


- (id)initWithTitle:(NSString *)title delegate:(id <HXOActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;

- (NSInteger) addButtonWithTitle: (NSString*) title;
- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex;
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;

@end
