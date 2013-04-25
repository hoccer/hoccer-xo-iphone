//
//  ProfileAvatarCell.h
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "AutoheightLabel.h"

@protocol UserDefaultsCellTextInputDelegate <NSObject>

@optional

- (BOOL) validateTextField: (UITextField*) textField;
- (void) textFieldDidEndEditing: (UITextField*) textField;

@end


@interface ProfileItem : NSObject <UserDefaultsCellTextInputDelegate>

@property (nonatomic,strong) UIImage  *      icon;
@property (nonatomic,strong) NSString *      valueKey; // used to access the model
@property (nonatomic,strong) NSString *      currentValue;
@property (nonatomic,strong) NSString *      editLabel;
@property (nonatomic,strong) id              cellClass;
@property (nonatomic,strong) NSString *      placeholder;
@property (nonatomic,assign) UIKeyboardType  keyboardType;
@property (nonatomic,assign) BOOL            required;
@property (nonatomic,assign) BOOL            valid;
@property (nonatomic,assign) UITextAlignment textAlignment;
@property (nonatomic, assign) BOOL           secure;
@property (nonatomic, weak)  id              target;
@property (nonatomic,assign) SEL             action;
@property (nonatomic,strong) NSIndexPath *   indexPath;
@property (nonatomic,assign) BOOL            alwaysShowDisclosure;

@end

@interface AvatarItem : NSObject

@property (nonatomic,strong) UIImage*  currentValue;
@property (nonatomic,strong) NSString* valueKey;
@property (nonatomic,strong) NSString* contactKey;
@property (nonatomic,strong) id        cellClass;
@property (nonatomic,weak) id        target;
@property (nonatomic, assign) SEL      action;
@property (nonatomic,strong) NSIndexPath *   indexPath;

@end



@class ProfileAvatarView;

@interface UserDefaultsCell : HXOTableViewCell

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) count;

- (void) configure: (id) item;

@end

@interface UserDefaultsCellAvatarPicker : UserDefaultsCell

@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;

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

@property (nonatomic,strong) IBOutlet AutoheightLabel * textLabel;

- (CGFloat) heightForText: (NSString*) text;

@end

@interface UserDefaultsCellDisclosure : UserDefaultsCell

@property (nonatomic,strong) NSString* editLabel;

@end
