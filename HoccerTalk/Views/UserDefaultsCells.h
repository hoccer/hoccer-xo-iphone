//
//  ProfileAvatarCell.h
//  HoccerTalk
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HoccerTalkTableViewCell.h"

@class ProfileAvatarView;

@interface UserDefaultsCell : HoccerTalkTableViewCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) count;

@end

@interface UserDefaultsCellAvatarPicker : UserDefaultsCell

@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;

@end

@protocol UserDefaultsCellTextInputDelegate <NSObject>

@optional

- (BOOL) validateTextField: (UITextField*) textField;
- (void) textFieldDidEndEditing: (UITextField*) textField;

@end

@interface UserDefaultsCellTextInput : UserDefaultsCell  <UITextFieldDelegate>

@property (nonatomic,strong) IBOutlet UITextField * textField;
@property (nonatomic,strong) IBOutlet UIImageView * textInputBackground;
@property (nonatomic,strong) NSString* editLabel;
@property (nonatomic,strong) id<UserDefaultsCellTextInputDelegate> delegate;

@end

@interface UserDefaultsCellSwitch: UserDefaultsCell

@property (nonatomic,strong) IBOutlet UISwitch * toggle;

@end

@interface UserDefaultsCellInfoText : UserDefaultsCell

@property (nonatomic,strong) IBOutlet UILabel * textLabel;

@end

@interface UserDefaultsCellDisclosure : UserDefaultsCell

@property (nonatomic,strong) NSString* editLabel;

@end
