//
//  ProfileAvatarCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserDefaultsCells.h"
#import "AssetStore.h"
#import "ProfileAvatarView.h"

static const CGFloat kEditAnimationDuration = 0.5;


@implementation ProfileItem

- (id) init {
    self = [super init];
    if (self != nil) {
        self.valid = YES;
        self.textAlignment = NSTextAlignmentLeft;
    }
    return self;
}

- (void) setRequired:(BOOL)required {
    _required = required;
    if (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""])) {
        self.valid = NO;
    }
}

- (void) setCurrentValue:(NSString *)currentValue {
    _currentValue = currentValue;
    if (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""])) {
        self.valid = NO;
    }
}

- (BOOL) validateTextField:(UITextField *)textField {
    self.currentValue = textField.text;
    if (self.required && ( textField.text == nil || [textField.text isEqualToString: @""])) {
        self.valid = NO;
    } else {
        self.valid = YES;
    }
    return self.valid;
}
@end

@implementation AvatarItem
@end



@implementation UserDefaultsCell

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self != nil) {
        [self setupLabel];
    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    [self setupLabel];
}

- (void) setupLabel {
    self.textLabel.shadowColor = [UIColor whiteColor];
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.textLabel.textColor = [UIColor colorWithWhite: 0.25 alpha: 1.0];
    self.textLabel.backgroundColor = [UIColor clearColor];
}

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount {
    UIImage * image;
    if (cellCount == 1) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_single" withLeftCapWidth: 4 topCapHeight: 4];
    } else if (position == 0) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_first" withLeftCapWidth: 4 topCapHeight: 4];
    } else if (position == cellCount - 1) {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg_last" withLeftCapWidth: 4 topCapHeight: 4];
    } else {
        image = [AssetStore stretchableImageNamed: @"user_defaults_cell_bg" withLeftCapWidth: 4 topCapHeight: 4];
    }
    self.backgroundView = [[UIImageView alloc] initWithImage: image];
}

- (void) configure: (id) item {
    self.imageView.image = [item icon];
    self.textLabel.textAlignment = [item textAlignment];
    self.textLabel.text = self.isEditing ? [item editLabel] : [item currentValue];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}


@end

@implementation UserDefaultsCellAvatarPicker

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) count {
    self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated: animated];
    self.avatar.enabled = editing;
    self.avatar.outerShadowColor = editing ? [UIColor orangeColor] : [UIColor whiteColor];
}

- (void) configure: (AvatarItem*) item {
    // does not call super class
    self.avatar.image = item.currentValue;
    if (self.avatar.defaultImage == nil) {
        self.avatar.defaultImage = [UIImage imageNamed: @"avatar_default_contact_large"];
    }
    [self.avatar addTarget: [item target] action: [item action] forControlEvents: UIControlEventTouchUpInside];
}

@end

@implementation UserDefaultsCellTextInput

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textField.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.textField];
    self.textInputBackground.image = [AssetStore stretchableImageNamed: @"profile_text_input_bg" withLeftCapWidth:3 topCapHeight:3];
    self.textInputBackground.frame = CGRectInset(self.textField.frame, -8, 2);
    self.textField.backgroundColor = [UIColor clearColor];
    self.textField.alpha = 0;
    self.textInputBackground.alpha = 0;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    if (editing != self.isEditing) {
        [super setEditing: editing animated: animated];
        if (animated) {
            [UIView animateWithDuration: kEditAnimationDuration animations:^{
                [self showEditControls: editing];
            }];
            [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                self.textLabel.alpha = 0;
            } completion:^(BOOL finished) {
                self.textLabel.text = editing ? self.editLabel : self.textField.text;
                [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                    self.textLabel.alpha = 1;
                }];
            }];
        } else {
            [self showEditControls: editing];
            self.textLabel.text = editing ? self.editLabel : self.textField.text;
        }
    }
}

- (void) showEditControls: (BOOL) editing {
    CGFloat alpha = editing ? 1 : 0;
    self.textField.alpha = alpha;
    self.textInputBackground.alpha = alpha;
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    if ([self.delegate respondsToSelector:@selector(textFieldDidEndEditing:)]) {
        [self.delegate textFieldDidEndEditing: self.textField];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.textField resignFirstResponder];
    return NO;
}

- (void) textFieldDidChange: (NSNotification*) notification {
    if ([self.delegate respondsToSelector: @selector(validateTextField:)]) {
        BOOL isValid = [self.delegate validateTextField: notification.object];
        self.textInputBackground.image = isValid ? [[self class] validBackground] : [[self class] invalidBackground];
    }
}

- (void) setDelegate:(id<UserDefaultsCellTextInputDelegate>)delegate {
    _delegate = delegate;
    if ([self.delegate respondsToSelector: @selector(validateTextField:)]) {
        BOOL isValid = [self.delegate validateTextField: self.textField];
        self.textInputBackground.image = isValid ? [[self class] validBackground] : [[self class] invalidBackground];
    }
}

- (void) configure: (id) item {
    [super configure: item];

    NSString * value = [item currentValue];
    self.textField.text = value;
    self.textField.placeholder = [item placeholder];
    self.delegate = item;
    self.editLabel = [item editLabel];

    self.textField.keyboardType = [item keyboardType];

    self.textField.secureTextEntry = [item secure];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (UIImage*) validBackground {
    return [AssetStore stretchableImageNamed: @"profile_text_input_bg" withLeftCapWidth:3 topCapHeight:3];
}

+ (UIImage*) invalidBackground {
    return [AssetStore stretchableImageNamed: @"profile_text_input_bg_invalid" withLeftCapWidth:3 topCapHeight:3];
}

@end

@implementation UserDefaultsCellSwitch

- (void) awakeFromNib {
    [super awakeFromNib];
    self.textLabel.font = [UIFont boldSystemFontOfSize: 14];
}

@end

@implementation UserDefaultsCellInfoText

- (CGFloat) heightForText: (NSString*) text {
    return [self.textLabel calculateSize: text].height + 22;
}

- (void) configure:(id)item {
    [super configure: item];
    [self.textLabel sizeToFit];
}

@end

@implementation UserDefaultsCellDisclosure

- (void) awakeFromNib {
    [super awakeFromNib];
    self.editingAccessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"user_defaults_disclosure_arrow"]];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated: animated];
    if (editing != self.isEditing) {
        if (animated) {
            [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                self.textLabel.alpha = 0;
            } completion:^(BOOL finished) {
                self.textLabel.text = editing ? self.editLabel : @"TODO";
                [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                    self.textLabel.alpha = 1;
                }];
            }];
        } else {
            self.textLabel.text = editing ? self.editLabel : @"TODO";
        }
    }
}


- (void) configure: (id) item {
    [super configure: item];
    self.editLabel = [item editLabel];
    if ([item alwaysShowDisclosure]) {
        self.accessoryView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"user_defaults_disclosure_arrow"]];
    }
}

@end
