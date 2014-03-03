//
//  ProfileAvatarCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserDefaultsCells.h"
#import "ProfileAvatarView.h"

static const CGFloat kEditAnimationDuration = 0.5;

extern CGFloat kHXOGridSpacing;

@implementation ProfileItem

- (id) initWithName:(NSString *)name {
    self = [super init];
    if (self != nil) {
        self.valid = YES;
        self.textAlignment = NSTextAlignmentLeft;
        self.name = name;
        self.isEditable = NO;
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
        CGFloat height = 3 * kHXOGridSpacing;
        CGFloat padding = 2 * kHXOGridSpacing;
        self.label = [[UILabel alloc] initWithFrame: CGRectMake(padding, padding, self.contentView.frame.size.width, height)];
        self.label.textColor = [UIColor colorWithWhite: 0.6 alpha: 1.0];
        self.label.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview: self.label];
    }
    return self;
}

- (CGSize) sizeThatFits:(CGSize)size {
    size = [self.label sizeThatFits: CGSizeMake(size.width,0)];
    size.height += 4 * kHXOGridSpacing;
    return size;
}


- (void) configure: (id) item {
    self.valueFormat = [item valueFormat];
    self.currentValue = [item currentValue];
    //self.imageView.image = [item icon];
    self.label.textAlignment = [item textAlignment];
    /*
    if (self.isEditing) {
        self.textLabel.text = [item editLabel];
    } else {
        self.textLabel.text = self.valueFormat == nil ? [item currentValue] : [self formattedValue];
    }
     */
    self.label.text = [item editLabel];
    [self.label sizeToFit];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

// ugly, iterative value formating to ellipsise at the right place
- (NSString*) formattedValue {
    CGFloat maxWidth = self.contentView.bounds.size.width - 20;
    NSString * value = self.currentValue;
    NSString * text = [NSString stringWithFormat: self.valueFormat, value];
#ifdef PRE_IOS7
    CGFloat width = [text sizeWithFont: self.label.font].width;
#else
    CGSize constraint = CGSizeMake(MAXFLOAT,MAXFLOAT);
    NSDictionary *attributes = @{ NSFontAttributeName: self.label.font};
    CGRect bounds = [text boundingRectWithSize:constraint options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes:attributes context:nil];
    CGFloat width = bounds.size.width;
#endif
    unichar ellipse = 0x2026;
    while (width > maxWidth && [value length] > 0) {
        value = [value substringToIndex: [value length] - 1];
        text = [NSString stringWithFormat: self.valueFormat, [NSString stringWithFormat: @"%@%C", value, ellipse]];
#ifdef PRE_IOS7
        width = [text sizeWithFont: self.label.font].width;
#else
        width = [text boundingRectWithSize:constraint options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading) attributes:attributes context:nil].size.width;
#endif
    }
    return text;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    if (self.valueFormat != nil && ! self.isEditing) {
        self.label.text = [self formattedValue];
        [self.label sizeToFit];
    }
}

@end

@implementation UserDefaultsCellTextInput

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self != nil) {
        self.textField = [[UITextField alloc] initWithFrame: CGRectMake(0, 2 * kHXOGridSpacing, 0, 3 * kHXOGridSpacing)];
        self.textField.enabled = NO;
        [self.contentView addSubview: self.textField];
        self.textField.delegate = self;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textFieldDidChange:)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:self.textField];

    }
    return self;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    self.textField.enabled = editing && [self.delegate isEditable];
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
    self.textField.enabled = [item isEditable] && self.isEditing;

    self.maxLength = [item maxLength];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    CGRect frame = self.textField.frame;
    frame.origin.x = CGRectGetMaxX(self.label.frame) + kHXOGridSpacing;
    frame.size.width = self.contentView.frame.size.width - frame.origin.x;
    self.textField.frame = frame;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

+ (UIImage*) validBackground {
    return [[UIImage imageNamed: @"profile_text_input_bg"] stretchableImageWithLeftCapWidth: 3 topCapHeight: 3];
}

+ (UIImage*) invalidBackground {
    return [[UIImage imageNamed: @"profile_text_input_bg_invalid"] stretchableImageWithLeftCapWidth: 3 topCapHeight: 3];
}

@end

@implementation UserDefaultsCellInfoText

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self) {
        self.label.font = [UIFont systemFontOfSize: 12];
        self.label.numberOfLines = 0;
    }
    return self;
}

- (void) configure:(id)item {
    [super configure: item];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self updateLabelFrame];
}

- (void) updateLabelFrame {
    CGFloat width = self.frame.size.width - 2 * kHXOGridSpacing;
    CGRect frame = self.label.frame;
    frame.size.width = width;
    frame.origin.x = 2 * kHXOGridSpacing;
    frame.origin.y = 2 * kHXOGridSpacing;
    self.label.frame = frame;
}

- (CGSize) sizeThatFits:(CGSize)size {
    size = [self.label sizeThatFits: size];
    size.height += 4 * kHXOGridSpacing;
    return size;
}

@end

@implementation UserDefaultsCellDisclosure

- (void) awakeFromNib {
    [super awakeFromNib];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing: editing animated: animated];
    if (editing != self.isEditing) {
        if (animated) {
            [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                self.label.alpha = 0;
            } completion:^(BOOL finished) {
                self.label.text = editing ? self.editLabel : @"TODO";
                [UIView animateWithDuration: 0.5 * kEditAnimationDuration animations:^{
                    self.label.alpha = 1;
                }];
            }];
        } else {
            self.label.text = editing ? self.editLabel : @"TODO";
        }
    }
}

- (void) configure: (id) item {
    [super configure: item];
    self.editLabel = [item editLabel];
    if ([item alwaysShowDisclosure]) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
}

@end
