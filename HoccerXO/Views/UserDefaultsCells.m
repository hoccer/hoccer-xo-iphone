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

- (id) initWithName:(NSString *)name {
    self = [super init];
    if (self != nil) {
        self.valid = YES;
        self.textAlignment = NSTextAlignmentLeft;
        self.name = name;
    }
    return self;
}

- (void) setRequired:(BOOL)required {
    _required = required;
    self.valid = ! (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""]));
}

- (void) setCurrentValue:(NSString *)currentValue {
    _currentValue = currentValue;
    self.valid = ! (_required && (self.currentValue == nil || [self.currentValue isEqualToString: @""]));
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
- (id) initWithName:(NSString *)name {
    self = [super init];
    if (self != nil) {
        self.name = name;
    }
    return self;
}
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

+ (void) configureGroupedCell: (UITableViewCell*) cell forPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount{
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
    cell.backgroundView = [[UIImageView alloc] initWithImage: image];

}

- (void) configureBackgroundViewForPosition: (NSUInteger) position inSectionWithCellCount: (NSUInteger) cellCount {
    [UserDefaultsCell configureGroupedCell: self forPosition: position inSectionWithCellCount: cellCount];
}

- (void) configure: (id) item {
    self.valueFormat = [item valueFormat];
    self.currentValue = [item currentValue];
    self.imageView.image = [item icon];
    self.textLabel.textAlignment = [item textAlignment];
    if (self.isEditing) {
        self.textLabel.text = [item editLabel];
    } else {
        self.textLabel.text = self.valueFormat == nil ? [item currentValue] : [self formattedValue];
    }
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

// ugly, iterative value formating to ellipsise at the right place
- (NSString*) formattedValue {
    CGFloat maxWidth = self.contentView.bounds.size.width - 20;
    NSString * value = self.currentValue;
    NSString * text = [NSString stringWithFormat: self.valueFormat, value];
    CGFloat width = [text sizeWithFont: self.textLabel.font].width;
    unichar ellipse = 0x2026;
    while (width > maxWidth && [value length] > 0) {
        value = [value substringToIndex: [value length] - 1];
        text = [NSString stringWithFormat: self.valueFormat, [NSString stringWithFormat: @"%@%C", value, ellipse]];
        width = [text sizeWithFont: self.textLabel.font].width;
    }
    return text;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    if (self.valueFormat != nil && ! self.isEditing) {
        self.textLabel.text = [self formattedValue];
    }
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
        self.avatar.defaultImage = [UIImage imageNamed: item.defaultImageName];
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

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (self.maxLength == 0) {
        return YES;
    }
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength > self.maxLength) ? NO : YES;
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

    self.maxLength = [item maxLength];
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
