//
//  HXOActionSheet.h
//  HoccerToolKit
//
//  Created by David Siegel on 26.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HXOSheetView.h"

@class HXOActionSheet;

@protocol HXOActionSheetDelegate <NSObject>
- (void)actionSheet:(HXOActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex;

@end

@interface HXOActionSheet : HXOSheetView
{
    NSMutableArray * _buttonTitles;
}

@property (nonatomic,assign) id<HXOActionSheetDelegate> delegate;

@property (nonatomic) NSInteger cancelButtonIndex;
@property (nonatomic) NSInteger destructiveButtonIndex;
@property (nonatomic,readonly) NSInteger firstOtherButtonIndex;
@property (nonatomic,readonly) NSInteger numberOfButtons;

@property (nonatomic,strong) UIImage * destructiveButtonBackgroundImage UI_APPEARANCE_SELECTOR;
@property (nonatomic,strong) UIImage * cancelButtonBackgroundImage      UI_APPEARANCE_SELECTOR;
@property (nonatomic,strong) UIImage * otherButtonBackgroundImage       UI_APPEARANCE_SELECTOR;


- (id)initWithTitle:(NSString *)title delegate:(id <HXOActionSheetDelegate>)delegate cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;

- (NSInteger) addButtonWithTitle: (NSString*) title;
- (NSString *)buttonTitleAtIndex:(NSInteger)buttonIndex;

@end
