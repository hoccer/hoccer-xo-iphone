//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AvatarView.h"
#import "Contact.h"
#import "ContactCell.h"
#import "Group.h"
#import "GroupMembership.h"
#import "HXOUI.h"
#import "HXOLabel.h"
#import "HXOPluralocalization.h"
#import "HXOUI.h"
#import "VectorArtView.h"

#import "avatar_contact.h"
#import "avatar_group.h"
#import "avatar_location.h"
#import "disclosure_arrow.h"

#define CELL_DEBUG NO

@interface ContactCell ()

@property (nonatomic,strong) NSArray * verticalConstraints;

@end

@implementation ContactCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    if (CELL_DEBUG) NSLog(@"ContactCell:commonInit");

    self.hxoAccessoryView = [[VectorArtView alloc] initWithVectorArt: [[disclosure_arrow alloc] init]];
    self.hxoAccessoryAlignment = HXOCellAccessoryAlignmentCenter;

    self.contentView.autoresizingMask |= UIViewAutoresizingFlexibleHeight;
    //self.separatorInset = UIEdgeInsetsMake(0, kHXOCellPadding + [self avatarSize] + kHXOCellPadding, 0, 0);

    _titleLabel = [[UILabel alloc] initWithFrame: CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.autoresizingMask = UIViewAutoresizingNone;
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    //_titleLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    _titleLabel.text = @"Random Joe";
    [self.contentView addSubview: _titleLabel];
    
    _subtitleLabel = [[HXOLabel alloc] initWithFrame: CGRectZero];
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.autoresizingMask = UIViewAutoresizingNone;
    _subtitleLabel.numberOfLines = 1;
    _subtitleLabel.text = @"Lorem ipsum";
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _subtitleLabel.textColor = [[HXOUI theme] lightTextColor];
    //_subtitleLabel.backgroundColor = [UIColor colorWithWhite: 0.96 alpha: 1.0];
    [self.contentView addSubview: _subtitleLabel];

    _avatar = [[AvatarView alloc] initWithFrame: CGRectMake(0, 0, [self avatarSize], [self avatarSize])];
    _avatar.autoresizingMask = UIViewAutoresizingNone;
    _avatar.translatesAutoresizingMaskIntoConstraints = NO;
    [_avatar addTarget: self action: @selector(avatarPressed:) forControlEvents: UIControlEventTouchUpInside];
    [self.contentView addSubview: _avatar];

    UIView * title = _titleLabel;
    UIView * subtitle = _subtitleLabel;
    UIView * image = _avatar;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle, image);
    
    [self addFirstRowHorizontalConstraints: views];
    
    NSString * format = [NSString stringWithFormat:  @"V:|-%f-[image(>=10)]-%f-|", [self verticalPadding], [self verticalPadding]];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];

    [self.contentView addConstraint: [NSLayoutConstraint constraintWithItem: self.avatar attribute: NSLayoutAttributeWidth relatedBy: NSLayoutRelationEqual toItem: self.avatar attribute: NSLayoutAttributeHeight multiplier: 1 constant: 0]];


    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self preferredContentSizeChanged: nil];
    self.delegate = nil;
}

- (CGFloat) avatarSize {
    return 10;
}

- (CGFloat) verticalPadding {
    return 1.5 * kHXOGridSpacing;
}

- (void) addFirstRowHorizontalConstraints: (NSDictionary*) views {
    if (CELL_DEBUG) NSLog(@"%@:layoutSubviews", [self class]);
    NSString * format = [NSString stringWithFormat: @"H:|-%f-[image]-%f-[title(>=0)]->=%f-|", kHXOCellPadding, kHXOCellPadding, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];
    format = [NSString stringWithFormat:  @"H:[image]-%f-[subtitle]->=%f-|", kHXOCellPadding, kHXOGridSpacing];
    [self.contentView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                              options: 0 metrics: nil views: views]];    
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    if (CELL_DEBUG) NSLog(@"%@:preferredContentSizeChanged", [self class]);
    self.titleLabel.font = [HXOUI theme].titleFont;
    //NSLog(@"nickname size %@", NSStringFromCGSize( self.titleLabel.intrinsicContentSize));
    self.subtitleLabel.font = [HXOUI theme].smallTextFont;
    
    if (self.verticalConstraints) {
        [self.contentView removeConstraints: self.verticalConstraints];
    }
    UIView * title = self.titleLabel;
    UIView * subtitle = self.subtitleLabel;
    NSDictionary * views = NSDictionaryOfVariableBindings(title, subtitle);
    CGFloat y = [self verticalPadding] - (self.titleLabel.font.ascender - self.titleLabel.font.capHeight);
    NSString * format = [NSString stringWithFormat: @"V:|-%f-[title]-%f-[subtitle]-(>=%f)-|", y, [self labelSpacing], [self verticalPadding]];
    self.verticalConstraints = [NSLayoutConstraint constraintsWithVisualFormat: format
                                                                       options: 0 metrics: nil views: views];
    [self.contentView addConstraints: self.verticalConstraints];
    
    [self setNeedsLayout];
}

- (CGFloat) labelSpacing {
    return 0;//0.25 * kHXOGridSpacing;
}

- (void) layoutSubviews {
    if (CELL_DEBUG) NSLog(@"%@:layoutSubviews", [self class]);
    [super layoutSubviews];
    UIEdgeInsets insets = self.separatorInset;
    insets.left = self.titleLabel.frame.origin.x;
    self.separatorInset = insets;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) setDelegate:(id<ContactCellDelegate>)delegate {
    _delegate = delegate;
    self.avatar.userInteractionEnabled = _delegate != nil;
}

- (void) avatarPressed: (id) sender {
    if ([self.delegate respondsToSelector: @selector(contactCellDidPressAvatar:)]) {
        [self.delegate contactCellDidPressAvatar: self];
    }
}

+ (void) configureCell:(UITableViewCell<ContactCell> *)cell forContact: (Contact *)contact {
    cell.delegate = nil;
    
    cell.titleLabel.text = contact.nickNameWithStatus;
    
    UIImage * avatar = contact.avatarImage;
    cell.avatar.image = avatar;
    cell.avatar.defaultIcon = [contact.type isEqualToString: [Group entityName]] ? [((Group*)contact).groupType isEqualToString: @"nearby"] ? [[avatar_location alloc] init] : [[avatar_group alloc] init] : [[avatar_contact alloc] init];
    cell.avatar.isBlocked = [contact isBlocked];
    cell.avatar.isPresent  = contact.isConnected && !contact.isKept;
    cell.avatar.isInBackground  = contact.isBackground;
    
    cell.subtitleLabel.text = [ContactCell statusStringForContact: contact];
}

+ (NSString*) statusStringForContact: (Contact*) contact {
    if ([contact isKindOfClass: [Group class]]) {
        // Man, this shit is disgusting. Needs de-monstering... I mean *really*. [agnat]
        Group * group = (Group*)contact;
        NSInteger joinedMemberCount = [group.otherJoinedMembers count];
        NSInteger invitedMemberCount = [group.otherInvitedMembers count];
        
        NSString * joinedStatus = @"";
        
        if (group.isKept) {
            joinedStatus = NSLocalizedString(@"group_state_kept", nil);
            
        } else if (group.myGroupMembership.isInvited){
            joinedStatus = NSLocalizedString(@"group_membership_state_invited", nil);
            
        } else {
            if (group.iAmAdmin) {
                joinedStatus = NSLocalizedString(@"group_membership_role_admin", nil);
            }
            if (joinedStatus.length>0) {
                joinedStatus = [joinedStatus stringByAppendingString: @", "];
            }
            joinedStatus =  [joinedStatus stringByAppendingString: [NSString stringWithFormat: HXOPluralocalizedString(@"group_member_count_joined", joinedMemberCount, YES), joinedMemberCount]];
            if (invitedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [joinedStatus stringByAppendingString: @", "];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_invited_count",nil), invitedMemberCount];
            }
#ifdef DEBUG
            if (group.sharedKeyId != nil) {
                joinedStatus = [[joinedStatus stringByAppendingString:@" "] stringByAppendingString:group.sharedKeyIdString];
            }
#endif
        }
        return joinedStatus;
    } else {
        NSString * relationshipKey = [NSString stringWithFormat: @"contact_relationship_%@", contact.relationshipState];
        return NSLocalizedString(relationshipKey, nil);
    }
}

@end
