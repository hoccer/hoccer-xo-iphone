//
//  DetailViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetExportSession.h>
#import <AVFoundation/AVMediaFormat.h>

#import "HXOMessage.h"
#import "Delivery.h"
#import "AppDelegate.h"
#import "AttachmentPickerController.h"
#import "MessageCell.h"
#import "HXOUserDefaults.h"
#import "ImageViewController.h"
#import "UserProfile.h"
#import "NSString+StringWithData.h"
#import "Vcard.h"
#import "NSData+Base64.h"
#import "Group.h"
#import "GroupMembership.h"
#import "UIAlertView+BlockExtensions.h"
#import "TextMessageCell.h"
#import "ImageAttachmentMessageCell.h"
#import "GenericAttachmentMessageCell.h"
#import "ImageAttachmentWithTextMessageCell.h"
#import "GenericAttachmentWithTextMessageCell.h"
#import "ImageAttachmentSection.h"
#import "TextSection.h"
#import "GenericAttachmentSection.h"
#import "ProfileViewController.h"
#import "LabelWithLED.h"
#import "UpDownLoadControl.h"
#import "DateSectionHeaderView.h"
#import "MessageItems.h"
#import "HXOHyperLabel.h"
#import "paper_dart.h"
#import "paper_clip.h"
#import "HXOUI.h"
#import "AvatarView.h"
#import "avatar_contact.h"
#import "AttachmentButton.h"
#import "GroupInStatuNascendi.h"
#import "HXOPluralocalization.h"

#define DEBUG_ATTACHMENT_BUTTONS NO
#define DEBUG_TABLE_CELLS NO
#define DEBUG_NOTIFICATIONS NO
#define DEBUG_APPEAR NO
#define READ_DEBUG NO
#define DEBUG_OBSERVERS NO

static const NSUInteger kMaxMessageBytes = 10000;
static const NSTimeInterval kTypingTimerInterval = 3;

static int ChatViewObserverContext = 0;

typedef void(^AttachmentImageCompletion)(Attachment*, AttachmentSection*);

@interface ChatViewController ()

@property (nonatomic, strong)   UIPopoverController *masterPopoverController;
@property (nonatomic, readonly) AttachmentPickerController    * attachmentPicker;
//@property (nonatomic, strong)   UIView                        * attachmentPreview;
@property (nonatomic, strong)   NSIndexPath                   * firstNewMessage;
@property (nonatomic, strong)   NSMutableDictionary           * cellPrototypes;
@property (nonatomic, strong)   MPMoviePlayerViewController   *  moviePlayerViewController;
@property (nonatomic, readonly) ImageViewController           * imageViewController;
@property (nonatomic, readonly) ABUnknownPersonViewController * vcardViewController;
@property (nonatomic, strong)   LabelWithLED                  * titleLabel;

@property (strong, nonatomic)   HXOMessage                    * messageToForward;

@property (nonatomic, readonly) NSMutableDictionary           * messageItems;
@property (nonatomic, readonly) NSDateFormatter               * dateFormatter;
@property (nonatomic, readonly) NSByteCountFormatter          * byteCountFormatter;

@property (nonatomic, strong)   UITextField                   * autoCorrectTriggerHelper;
@property (nonatomic, strong)   UILabel                       * messageFieldPlaceholder;
@property (nonatomic, strong)   NSTimer                       * typingTimer;

@property  BOOL                                                keyboardShown;

@property (strong) UIBarButtonItem * actionButton;

@property (strong) id throwObserver;
@property (strong) id catchObserver;
@property (strong) id loginObserver;

@property (nonatomic, readonly) NSMutableSet * observedContacts;
@property (nonatomic, readonly) NSMutableSet * observedMembersGroups;

@end


@implementation ChatViewController

//@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;
@synthesize moviePlayerViewController = _moviePlayerViewController;
@synthesize imageViewController = _imageViewController;
@synthesize vcardViewController = _vcardViewController;
@synthesize currentExportSession = _currentExportSession;
@synthesize currentPickInfo = _currentPickInfo;
@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize messageItems = _messageItems;
@synthesize dateFormatter = _dateFormatter;
@synthesize byteCountFormatter = _byteCountFormatter;
@synthesize observedContacts = _observedContacts;
@synthesize observedMembersGroups = _observedMembersGroups;

-(NSMutableSet *)observedContacts {
    if (_observedContacts == nil) {
        _observedContacts = [NSMutableSet new];
    }
    return _observedContacts;
}

-(NSMutableSet *)observedMembersGroups {
    if (_observedMembersGroups == nil) {
        _observedMembersGroups = [NSMutableSet new];
    }
    return _observedMembersGroups;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (DEBUG_APPEAR) NSLog(@"ChatViewController:viewDidLoad");
 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];

    [self setupChatbar];
    
    self.actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAction target: self action: @selector(actionButtonPressed:)];

    [HXOBackend registerConnectionInfoObserverFor:self];
    
    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [self.view addGestureRecognizer:gr];

    [self registerCellClass: [TextMessageCell class]];
    [self registerCellClass: [ImageAttachmentMessageCell class]];
    [self registerCellClass: [GenericAttachmentMessageCell class]];
    [self registerCellClass: [ImageAttachmentWithTextMessageCell class]];
    [self registerCellClass: [GenericAttachmentWithTextMessageCell class]];
    [self.tableView registerClass: [DateSectionHeaderView class] forHeaderFooterViewReuseIdentifier: @"date_header"];

    self.titleLabel = [[LabelWithLED alloc] init];
    self.navigationItem.titleView = self.titleLabel;
    self.titleLabel.textColor = [[HXOUI theme] navigationBarTintColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    // XXX do this in a more general way...
    self.titleLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleHeadline];

    [self configureView];
}

- (void)checkActionButtonVisible {
    //NSLog(@"partner %d, button %@, entries %d",self.partner != nil, self.navigationItem.rightBarButtonItem , [self actionButtonContainsEntries]);
    if (self.partner != nil && [self actionButtonContainsEntries]) {
        if (self.navigationItem.rightBarButtonItem == nil) {
            //NSLog(@"checkActionButtonVisible: on");
            self.navigationItem.rightBarButtonItem = self.actionButton;
        }
    } else if (self.navigationItem.rightBarButtonItem != nil) {
        // NSLog(@"checkActionButtonVisible: off");
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void) setupChatbar {
    self.autoCorrectTriggerHelper = [[UITextField alloc] init];
    self.autoCorrectTriggerHelper.hidden = YES;
    [self.chatbar addSubview: self.autoCorrectTriggerHelper];

    UIFont * font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];

    CGFloat s = 50; // magic toolbar size

    UIImage * icon = [[paper_clip alloc] init].image;
    self.attachmentButton = [[AttachmentButton alloc] initWithFrame: CGRectMake(0, 0, s, s)];
    self.attachmentButton.frame = CGRectMake(0, 0, 50, s);
    self.attachmentButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    //attachmentButton.backgroundColor = [UIColor orangeColor];
    //[attachmentButton setImage: icon forState: UIControlStateNormal];
    [self.attachmentButton addTarget: self action:@selector(attachmentPressed:) forControlEvents: UIControlEventTouchUpInside];
    //attachmentButton.enabled = NO;
    [self.chatbar addSubview: self.attachmentButton];

    CGFloat height = MIN(150, MAX( s - 2 * kHXOGridSpacing, 0));
    self.messageField = [[UITextView alloc] initWithFrame: CGRectMake(s, kHXOGridSpacing, self.chatbar.bounds.size.width - 2 * s, height)];
    self.messageField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageField.delegate = self;
    self.messageField.backgroundColor = [UIColor whiteColor];
    self.messageField.layer.cornerRadius = kHXOGridSpacing / 2;
    self.messageField.layer.borderWidth = 1.0;
    self.messageField.layer.borderColor = [HXOUI theme].messageFieldBorderColor.CGColor;
    self.messageField.font = font;
    self.messageField.textContainerInset = UIEdgeInsetsMake(6, 0, 2, 0);
    // This is important to keep the message field from erratic resizing:
    // set text to something before adding the field to the view hirarchy
    self.messageField.text = @"k";
    [self.messageField addObserver: self forKeyPath: @"contentSize" options: 0 context: nil];
    [self.chatbar addSubview: self.messageField];
    self.messageField.text = @"";

    CGRect frame = CGRectInset(self.messageField.frame, 5, 1); // experimentally found... :-/
    self.messageFieldPlaceholder = [[UILabel alloc] initWithFrame: frame];
    self.messageFieldPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.messageFieldPlaceholder.font = self.messageField.font;
    self.messageFieldPlaceholder.textColor = [HXOUI theme].lightTextColor;
    self.messageFieldPlaceholder.text = NSLocalizedString(@"chat_message_placeholder", nil);
    [self.chatbar addSubview: self.messageFieldPlaceholder];

    icon = [[paper_dart alloc] init].image;
    self.sendButton = [UIButton buttonWithType: UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(CGRectGetMaxX(self.messageField.frame), 0, s, s);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    //sendButton.backgroundColor = [UIColor orangeColor];
    [self.sendButton setImage: icon forState: UIControlStateNormal];
    [self.sendButton addTarget: self action:@selector(sendPressed:) forControlEvents: UIControlEventTouchUpInside];
    //sendButton.enabled = NO;
    [self.chatbar addSubview: self.sendButton];
}

- (UIMenuController *)setupLongPressMenu {
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    UIMenuItem *mySaveMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"save", nil) action:@selector(saveMessage:)];
    UIMenuItem *myDeleteMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"delete", nil) action:@selector(deleteMessage:)];
    UIMenuItem *myResendMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"chat_resend_menu_item", nil) action:@selector(resendMessage:)];
    UIMenuItem *myOpenWithMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"chat_open_with_menu_item", nil) action:@selector(openWithMessage:)];
    UIMenuItem *myShareMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"chat_share_menu_item", nil) action:@selector(shareMessage:)];
    [menuController setMenuItems:@[myShareMessageMenuItem,myOpenWithMessageMenuItem,myDeleteMessageMenuItem,myResendMessageMenuItem/*, myForwardMessageMenuItem*/,mySaveMenuItem]];
    [menuController update];
    return menuController;
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    //NSLog(@"ChatViewController:handleLongPress");
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint p = [gestureRecognizer locationInView: self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
        if (indexPath != nil) {
            //NSLog(@"ChatViewController:handleLongPress:path=%@", indexPath);
            
            UITableViewCell * myCell = [self.tableView cellForRowAtIndexPath:indexPath];
            //NSLog(@"ChatViewController:handleLongPress:myCell=%@", myCell);

            [myCell becomeFirstResponder];
            
            UIMenuController * menu = [self setupLongPressMenu];
            [menu setTargetRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView];
            [menu setMenuVisible:YES animated:YES];
            //NSLog(@"ChatViewController:handleLongPress:setMenuVisible");
        }
    }
 }

- (NSDateFormatter*) dateFormatter {
    if ( ! _dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateStyle:NSDateFormatterLongStyle];
        [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        [_dateFormatter setDoesRelativeDateFormatting:YES];
    }
    return _dateFormatter;
}

- (NSByteCountFormatter*) byteCountFormatter {
    if ( ! _byteCountFormatter) {
        _byteCountFormatter = [[NSByteCountFormatter alloc] init];
        _byteCountFormatter.countStyle = NSByteCountFormatterCountStyleFile;
    }
    return _byteCountFormatter;
}


- (void) viewWillAppear:(BOOL)animated {
    if (DEBUG_APPEAR) NSLog(@"ChatViewController:viewWillAppear");
    self.fetchedResultsController.delegate = self;
    [super viewWillAppear: animated];

    [HXOBackend broadcastConnectionInfo];

    [self scrollToRememberedCellOrToBottomIfNone];
    [AppDelegate setWhiteFontStatusbarForViewController:self];
    
    self.throwObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"gesturesInterpreterDidDetectThrow"
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification *note) {
                                                                    if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: Throw");
                                                                    if (self.sendButton.enabled) {
                                                                        [self sendPressed:nil];
                                                                    }
                                                                }];

    self.catchObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"gesturesInterpreterDidDetectCatch"
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *note) {
                                                                           if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: Catch");
                                                                       }];
    self.loginObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"loginSucceeded"
                                                                           object:nil
                                                                            queue:[NSOperationQueue mainQueue]
                                                                       usingBlock:^(NSNotification *note) {
                                                                           if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: loginSucceeded");
                                                                           [AppDelegate.instance configureForNearbyMode:self.partner.isNearby];
                                                                       }];
}

- (NSMutableDictionary*) messageItems {
    if ( ! _messageItems ) {
        _messageItems = [[NSMutableDictionary alloc] init];
    }
    return _messageItems;
}

- (MessageItem*) getItemWithMessage: (HXOMessage*) message {
    MessageItem * item = [self.messageItems objectForKey: message.objectID];
    if ( ! item) {
        item = [[MessageItem alloc] initWithMessage: message];
        [self.messageItems setObject: item forKey: message.objectID];
    }
    item.message = message;
    return item;
}

- (void) viewWillDisappear:(BOOL)animated {
    [self rememberLastVisibleCell];
    if (self.throwObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.throwObserver];
    }
    if (self.catchObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.catchObserver];
    }
    if (self.loginObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.loginObserver];
    }
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    if (DEBUG_APPEAR) NSLog(@"ChatViewController:viewDidDisappear");
    if ([self isMovingFromParentViewController]) {
        if (DEBUG_APPEAR) NSLog(@"isMovingFromParentViewController");
        [AppDelegate.instance endInspecting:self.partner withInspector:self];
        self.inspectedObject = nil;
    }
    if ([self isBeingDismissed]) {
        if (DEBUG_APPEAR) NSLog(@"isBeingDismissed");
    }
    self.fetchedResultsController.delegate = nil;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    _messageItems = nil;
    resultsControllers = nil;
}

- (void)configureView {
    if (self.partner) {
        [self configureTitle];
        [self checkActionButtonVisible];
    }
}

- (void) configureTitle {
    self.titleLabel.text = self.partner.nickNameWithStatus;
    self.titleLabel.ledOn = self.partner.isConnected;
    self.titleLabel.ledColor = self.partner.isBackground ? HXOUI.theme.avatarOnlineInBackgroundLedColor : HXOUI.theme.avatarOnlineLedColor;
    [self.titleLabel sizeToFit];
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    for (id key in _cellPrototypes) {
        for (id section in [_cellPrototypes[key] sections])
        if ([section respondsToSelector: @selector(preferredContentSizeChanged:)]) {
            [section preferredContentSizeChanged: notification];
        }
    }
    self.messageField.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    self.messageFieldPlaceholder.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    [self updateVisibleCells];
    [self.tableView reloadData];
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"contact_list_nav_title", @"Contacts Navigation Bar Title");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - UITextViewDelegate Methods

- (void) textViewDidChange:(UITextView *)textView {
    if ([textView isEqual: self.messageField]) {
        self.messageFieldPlaceholder.alpha = textView.text && ! [textView.text isEqualToString:@""] ? 0 : 1;
        [self userDidType];
    }
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification*) notification {
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat height = orientation == UIInterfaceOrientationIsPortrait(orientation) ? keyboardFrame.size.height : keyboardFrame.size.width;
    CGPoint contentOffset = self.tableView.contentOffset;
    contentOffset.y += height;

    [UIView animateWithDuration: duration delay: 0 options: curve animations:^{
        self.keyboardHeight.constant = height;
        self.tableView.contentOffset = contentOffset;
        [self.view layoutIfNeeded];
    } completion: nil];
    
    self.keyboardShown = YES;
}

- (void)keyboardWillHide:(NSNotification*) notification {
    NSTimeInterval duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];

    [UIView animateWithDuration: duration delay: 0 options: curve animations:^{
        self.keyboardHeight.constant = 0;
        [self.view layoutIfNeeded];
    } completion: nil];
    self.keyboardShown = NO;
}

- (void) hideKeyboard {
    if (self.keyboardShown) {
        [self.view endEditing: NO];
    }
}

#pragma mark - Typing State Handling

- (void) userDidType {
    if (self.typingTimer) {
        [self.typingTimer invalidate];
        self.typingTimer = nil;
    }

    self.typingTimer = [NSTimer scheduledTimerWithTimeInterval: kTypingTimerInterval target: self selector: @selector(typingTimerFired:) userInfo: nil repeats: NO];
    [self.chatBackend changePresenceToTyping];
}

- (void) typingTimerFired: (NSTimer*) timer {
    [self.chatBackend changePresenceToNotTyping];
    self.typingTimer = nil;
}

#pragma mark - Actions

- (NSArray*) allMessagesInChat {
    NSDictionary * vars = @{ @"contact" : self.partner };
    NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByContact" substitutionVariables: vars];
    NSError * error;
    NSArray *messages = [AppDelegate.instance.mainObjectContext executeFetchRequest:fetchRequest error:&error];
    if (messages == nil) {
        NSLog(@"Fetch request failed: %@", error);
        abort();
    }
    return messages;
}

- (NSArray*) allMessagesInChatBeforeTime:(NSDate *)beforeTime {
    NSDate * since = [NSDate dateWithTimeIntervalSince1970:0];
    return [HXOBackend messagesByContact:self.partner inIntervalSinceTime:since beforeTime:beforeTime];
}

- (NSArray*) allMessagesBeforeVisible {
    NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
    if (indexPaths.count) {
        HXOMessage * message = (HXOMessage*)[self.fetchedResultsController objectAtIndexPath:indexPaths[0]];
        NSDate * referenceDate = message.timeAccepted;
        return [self allMessagesInChatBeforeTime:referenceDate];
    }
    return @[];
}

- (void) askDeleteMessages:(NSArray*)messages {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            NSArray * ids = objectIds(messages);
            [AppDelegate.instance performWithoutLockingInNewBackgroundContext:^(NSManagedObjectContext *context) {
                NSArray * messages = managedObjects(ids, context);
                for (HXOMessage * message in messages) {
                    [AppDelegate.instance deleteObject:message inContext:context];
                }
            }];
        }
    };
    
    NSString * title = [NSString stringWithFormat:HXOPluralocalizedString(@"chat_messages_delete_safety_question %d", messages.count, NO), messages.count];
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: title
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.view];
}

// Return nil when __INDEX__ is beyond the bounds of the array
#define NSArrayObjectMaybeNil(__ARRAY__, __INDEX__) ((__INDEX__ >= [__ARRAY__ count]) ? nil : [__ARRAY__ objectAtIndex:__INDEX__])

// Manually expand an array into an argument list
#define NSArrayToVariableArgumentsList(__ARRAYNAME__)\
NSArrayObjectMaybeNil(__ARRAYNAME__, 0),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 1),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 2),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 3),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 4),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 5),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 6),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 7),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 8),\
NSArrayObjectMaybeNil(__ARRAYNAME__, 9),\
nil

- (BOOL)actionButtonContainsEntries {
    //NSLog(@"actionButtonContainsEntries: %d %d %d",[[self.fetchedResultsController sections] count], self.partner.isGroup,((Group*)self.partner).otherMembers.count > 0);
    return self.partner != nil && ([[self.fetchedResultsController sections] count] > 0 || (self.partner.isGroup && ((Group*)self.partner).otherMembers.count > 0));
}

- (void) actionButtonPressed: (id) sender {
    
    NSArray * allMessagesInChat = [self allMessagesInChat];
    NSArray * allMessagesBeforeVisible = [self allMessagesBeforeVisible];
    
    NSSet * membersInvitable = nil;
    NSSet * membersInvitedMe = nil;
    NSSet * membersInvited = nil;
    NSSet * membersOther = nil;
    Group * group = nil;
    
    if (self.partner.isGroup) {
        group = (Group*)self.partner;
        membersInvitable = group.membersInvitable;
        membersInvitedMe = group.membersInvitedMeAsFriend;
        membersInvited = group.membersInvitedAsFriend;
        membersOther = group.otherMembers;
    }
    
    int buttonIndex = 0;
    NSMutableArray * buttonTitles = [NSMutableArray new];
    
    int deleteAllIndex = -1;
    if (allMessagesInChat.count > 0) {
        deleteAllIndex = buttonIndex++;
        [buttonTitles addObject: HXOPluralocalizeInt(@"chat_messages_delete_all %d", allMessagesInChat.count)];
    }
    
    int deletePreviousIndex = -1;
    if (allMessagesBeforeVisible.count > 0) {
        deletePreviousIndex = buttonIndex++;
        [buttonTitles addObject: HXOPluralocalizeInt(@"chat_messages_delete_all_previous %d", allMessagesBeforeVisible.count)];
    }

    int invitableIndex = -1;
    if (membersInvitable.count > 0) {
        invitableIndex = buttonIndex++;
        [buttonTitles addObject: HXOPluralocalizeInt(@"chat_group_members_invite %d", membersInvitable.count)];
    }

    int inviteMeIndex = -1;
    if (membersInvitedMe.count > 0) {
        inviteMeIndex = buttonIndex++;
        [buttonTitles addObject: HXOPluralocalizeInt(@"chat_group_members_invite_accept %d", membersInvitedMe.count)];
    }
    
    int invitedIndex = -1;
    if (membersInvited.count > 0) {
        invitedIndex = buttonIndex++;
        [buttonTitles addObject: HXOPluralocalizeInt(@"chat_group_members_disinvite %d", membersInvited.count)];
    }

    int makeGroupIndex = -1;
    if (membersOther.count > 0) {
        makeGroupIndex = buttonIndex++;
        [buttonTitles addObject: NSLocalizedString(@"chat_group_create_new_from_group", nil)];
    }
    
    if (buttonIndex == 0) {
        // return when nothing can be shown
        return;
    }
    
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        
        if (buttonIndex == deleteAllIndex) {
            [self askDeleteMessages:allMessagesInChat];
            
        } else if (buttonIndex == deletePreviousIndex) {
            [self askDeleteMessages:allMessagesBeforeVisible];
            
        } else if (buttonIndex == invitableIndex) {
            for (GroupMembership* member in membersInvitable) {
                [self.chatBackend inviteFriend:member.contact.clientId handler:^(BOOL ok) {
                    if (!ok) {
                        [self.chatBackend inviteFriendFailedAlertForContact:member.contact];
                    }
                }];
            }
            
        } else if (buttonIndex == inviteMeIndex) {
            for (GroupMembership* member in membersInvitedMe) {
                [self.chatBackend acceptFriend:member.contact.clientId handler:^(BOOL ok) {
                    if (!ok) {
                        [self.chatBackend acceptFriendFailedAlertForContact:member.contact];
                    }
                }];
            }
            
        } else if (buttonIndex == invitedIndex) {
            for (GroupMembership* member in membersInvited) {
                [self.chatBackend disinviteFriend:member.contact.clientId handler:^(BOOL ok) {
                    if (!ok) {
                        [self.chatBackend disinviteFriendFailedAlertForContact:member.contact];
                    }
                }];
            }
        } else if (buttonIndex == makeGroupIndex) {
            [self performSegueWithIdentifier: @"newGroup" sender: self.actionButton];
       }
    };
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"chat_action_sheet_title", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: NSArrayToVariableArgumentsList(buttonTitles)];
    
    [sheet showInView: self.view];

}

- (IBAction)sendPressed:(id)sender {
    NSString * cantSendTitle = NSLocalizedString(@"chat_cant_send_alert_title", nil);
    if ([self.partner.type isEqualToString:[Group entityName]]) {
        // check if there are other members in the group
        Group * group = (Group*)self.partner;
        if ([[group otherJoinedMembers] count] == 0 || group.isKeptGroup) {
            // cant send message, no other joined members
            NSString * messageText;
            if ([[group otherInvitedMembers] count] > 0) {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_wait_for_invitees_message", nil)];
            } else {
                if (group.isNearby) {
                    messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_nearby_group_you_are_alone_message", nil)];
                } else {
                    messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_group_you_are_alone_message", nil)];
                }
            }
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: cantSendTitle
                                                             message: messageText
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            return;
        }

        if ([HXOBackend isInvalid:group.groupKey]) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: cantSendTitle
                                                             message: NSLocalizedString(@"chat_no_groupkey_message", nil)
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            return;
            
        }
    } else if (!self.partner.isFriend) {
        NSString * messageText = nil;
        if (self.partner.isBlocked) {
            messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_contact_blocked_message", nil)];
        } else if (self.partner.isNearby) {
            if (!self.partner.isPresent) {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_nearby_contact_offline", nil)];
            }
        } else {
            messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_relationship_removed_message", nil)];
        }
        if (messageText != nil) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: cantSendTitle
                                                             message: messageText
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            return;
        }
    }

    // TODO: find a better way to detect that we have an attachment... :-/
    BOOL hasAttachmentPreview = self.attachmentButton.icon != nil || self.attachmentButton.previewImage != nil;
    if (self.messageField.text.length > 0 || hasAttachmentPreview) {
        if (self.currentAttachment == nil || self.currentAttachment.contentSize > 0) {
            if ([self.messageField.text lengthOfBytesUsingEncoding: NSUTF8StringEncoding] > kMaxMessageBytes) {
                NSString * messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_message_too_long_message", nil), kMaxMessageBytes];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: cantSendTitle
                                                                 message: messageText
                                                                delegate: nil
                                                       cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                       otherButtonTitles: nil];
                [alert show];
                return;
            }
            if (self.currentAttachment != nil && [self.currentAttachment overTransferLimit:YES]) {
                NSString * attachmentSize = [NSString stringWithFormat:@"%1.03f MB",[self.currentAttachment.contentSize doubleValue]/1024/1024];
                NSString * message = [NSString stringWithFormat: NSLocalizedString(@"attachment_overlimit_upload_question",nil), attachmentSize];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"attachment_overlimit_title", nil)
                                                                 message: message
                                                         completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                             switch (buttonIndex) {
                                                                  case 0:
                                                                     // do not send pressed, do nothing
                                                                     break;
                                                                 case 1:
                                                                     [self reallySendMessage];
                                                                     break;
                                                             }
                                                         }
                                                       cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                                       otherButtonTitles: NSLocalizedString(@"attachment_overlimit_confirm",nil),nil];
                [alert show];

            } else {
                [self reallySendMessage];
            }
            return;
        } else {
            // attachment content processing in progess, probably audio export
            NSLog(@"ERROR: sendPressed called while attachment not ready, should not happen");
            return;
        }
    }
    [self trashCurrentAttachment]; // will be trashed only in case it is still set, otherwise only view will be cleared
}

- (void)reallySendMessage {
    if ([self.messageField isFirstResponder]) {
        [self.autoCorrectTriggerHelper becomeFirstResponder]; // trigger autocompletion on last word ...
        [self.messageField becomeFirstResponder];     // ... without hiding the keyboard
    }
    [self.chatBackend sendMessage:self.messageField.text toContactOrGroup:self.partner toGroupMemberOnly:nil withAttachment:self.currentAttachment];
    self.currentAttachment = nil;
    self.messageField.text = @"";
    [self textViewDidChange: self.messageField];
    if (self.typingTimer) {
        [self.typingTimer fire];
    }
    [self trashCurrentAttachment];
}

- (IBAction)attachmentPressed: (id)sender {
    // NSLog(@"attachmentPressed");
    [self.messageField resignFirstResponder]; // XXX :-/
    if (_currentPickInfo || _currentAttachment) {
        [self showAttachmentOptions];
    } else {
        [self.attachmentPicker showInView: self.view];
    }
}

- (IBAction)cancelAttachmentProcessingPressed: (id)sender {
    // NSLog(@"cancelPressed");
    //[self.messageField resignFirstResponder];
    [self showAttachmentOptions];
}

- (IBAction) unwindToChatView: (UIStoryboardSegue*) unwindSegue {
    NSLog(@"ChatViewController:unwindToChatView");
}

- (UIViewController*)unwindToRootController {
    return self;
}

#pragma mark - Attachments

- (AttachmentPickerController*) attachmentPicker {
    _attachmentPicker = [[AttachmentPickerController alloc] initWithViewController: self delegate: self];
    return _attachmentPicker;
}

// unused yet, but may need it in the future
+ (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return nil;
}

- (void) didPickAttachment: (id) attachmentInfo {
    if (attachmentInfo == nil) {
        return;
    }
    [self startPickedAttachmentProcessingForObject:attachmentInfo];
    //NSLog(@"didPickAttachment: attachmentInfo = %@",attachmentInfo);

    self.currentAttachment = (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                        inManagedObjectContext: AppDelegate.instance.mainObjectContext];

    // handle geolocation
    if ([attachmentInfo isKindOfClass: [NSDictionary class]] &&
        [attachmentInfo[@"com.hoccer.xo.mediaType"] isEqualToString: @"geolocation"] &&
        [attachmentInfo[@"com.hoccer.xo.previewImage"] isKindOfClass: [UIImage class]])
    {
        MKPointAnnotation * placemark = attachmentInfo[@"com.hoccer.xo.geolocation"];
        NSLog(@"got geolocation %f %f", placemark.coordinate.latitude, placemark.coordinate.longitude);

        UIImage * preview = attachmentInfo[@"com.hoccer.xo.previewImage"];
        //float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        //NSData * previewData = UIImageJPEGRepresentation( preview, photoQualityCompressionSetting/10.0);
        NSData * previewData = UIImagePNGRepresentation( preview );

        NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike: @"location.json"];
        NSDictionary * json = @{ @"location": @{ @"type": @"point",
                                                 @"coordinates": @[ @(placemark.coordinate.latitude), @(placemark.coordinate.longitude)]},
                                 @"previewImage": [previewData asBase64EncodedString]};
        NSError * error;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject: json options: 0 error: &error];
        if ( jsonData == nil) {
            NSLog(@"failed to generate geojson: %@", error);
            [self finishPickedAttachmentProcessingWithImage: nil withError: error];
            return;
        }
        [jsonData writeToURL:myLocalURL atomically:NO];


        [self.currentAttachment makeGeoLocationAttachment: [myLocalURL absoluteString] anOtherURL: nil withCompletion:^(NSError *theError) {
            [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError: theError];
        }];
        return;
    }

    // handle vcard picked from adressbook
    if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        if (attachmentInfo[@"com.hoccer.xo.vcard.data"] != nil) {
            NSData * vcardData = attachmentInfo[@"com.hoccer.xo.vcard.data"];
            // NSString * vcardString = [NSString stringWithData:vcardData usingEncoding:NSUTF8StringEncoding];
            NSString * personName = attachmentInfo[@"com.hoccer.xo.vcard.name"];
            
            // find a suitable unique file name and path
            NSString * newFileName = [NSString stringWithFormat:@"%@.vcf",personName];
            NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
            
            [vcardData writeToURL:myLocalURL atomically:NO];
            CompletionBlock completion  = ^(NSError *myerror) {
                UIImage * preview = self.currentAttachment.previewImage != nil ? self.currentAttachment.previewImage : [UIImage imageNamed: @"attachment_icon_contact"];
                [self finishPickedAttachmentProcessingWithImage: preview withError:myerror];
            };
            self.currentAttachment.humanReadableFileName = [myLocalURL lastPathComponent];
            [self.currentAttachment makeVcardAttachment:[myLocalURL absoluteString] anOtherURL:nil withCompletion:completion];
            return;
        }
    }
    
    // handle stuff from pasteboard
    if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        if (attachmentInfo[@"com.hoccer.xo.mediaType"] != nil) {
            // attachment from pasteBoard
            NSString * myMediaType = attachmentInfo[@"com.hoccer.xo.mediaType"];
            self.currentAttachment.mimeType = attachmentInfo[@"com.hoccer.xo.mimeType"];
            self.currentAttachment.humanReadableFileName = attachmentInfo[@"com.hoccer.xo.fileName"];
            
            CompletionBlock completion  = ^(NSError *myerror) {
                [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:myerror];
            };
            
            if ([myMediaType isEqualToString:@"image"]) {
                [self.currentAttachment makeImageAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] image:nil withCompletion:completion];
            } else if ([myMediaType isEqualToString:@"video"]) {
                [self.currentAttachment makeVideoAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
            } else if ([myMediaType isEqualToString:@"audio"]) {
                [self.currentAttachment makeAudioAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
            } else if ([myMediaType isEqualToString:@"vcard"]) {
                [self.currentAttachment makeVcardAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
            } else if ([myMediaType isEqualToString:@"geolocation"]) {
                [self.currentAttachment makeGeoLocationAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
            } else if ([myMediaType isEqualToString:@"data"]) {
                [self.currentAttachment makeDataAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
            }
            return;
        }
        
        // check if pasted image
        id myImageObject = attachmentInfo[@"com.hoccer.xo.pastedImage"];
        if (myImageObject != nil) {
            UIImage * myImage = nil;
            if ([myImageObject isKindOfClass: [NSData class]]) {
                myImage = [UIImage imageWithData:myImageObject];
            } else if ([myImageObject isKindOfClass: [UIImage class]]) {
                myImage = (UIImage*) myImageObject;
            }
            if (myImage != nil) {
                // handle image from pasteboard
                
                // find a suitable unique file name and path
                NSString * newFileName = @"pastedImage.jpg";
                NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
                                
                // write the image
                myImage = [Attachment qualityAdjustedImage:myImage];
                float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myLocalURL atomically:NO];
                                
                [self.currentAttachment makeImageAttachment: [myLocalURL absoluteString] anOtherURL:nil
                                                      image: myImage
                                             withCompletion:^(NSError *theError) {
                                                 [self finishPickedAttachmentProcessingWithImage: myImage withError:theError];
                                             }];
                return;
            } else {
                NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: com.hoccer.xo.pastedImage is not an image, object is of class = %@", [myImageObject class]];
                NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 555 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
               
                [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                return;
            }
        }
    }
    
    if ([attachmentInfo isKindOfClass: [MPMediaItem class]]) {

        // probably an audio item media library
        MPMediaItem * song = (MPMediaItem*)attachmentInfo;
        
        // make a nice and unique filename
        NSString * newFileName = [NSString stringWithFormat:@"%@ - %@.%@",[song valueForProperty:MPMediaItemPropertyArtist],[song valueForProperty:MPMediaItemPropertyTitle],@"m4a" ];

        NSURL * myExportURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
        
        NSURL *assetURL = [song valueForProperty:MPMediaItemPropertyAssetURL];
        // NSLog(@"audio assetURL = %@", assetURL);
        
        AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
        
        if ([songAsset hasProtectedContent] == YES) {
            // TODO: user dialog here
            NSLog(@"Media is protected by DRM");
            NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: Media is protected by DRM"];
            NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 557 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
            return;
        }
        if (_currentExportSession != nil) {
            NSString * myDescription = [NSString stringWithFormat:@"An audio or video export is still in progress"];
            NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
            return;
        }
        
        _currentExportSession = [[AVAssetExportSession alloc]
                                  initWithAsset: songAsset
                                  presetName: AVAssetExportPresetAppleM4A];
        
        
        _currentExportSession.outputURL = myExportURL;
        _currentExportSession.outputFileType = AVFileTypeAppleM4A;
        _currentExportSession.shouldOptimizeForNetworkUse = YES;
        // exporter.shouldOptimizeForNetworkUse = NO;
        
        [AppDelegate setProcessingAudioSession];
        
        [_currentExportSession exportAsynchronouslyWithCompletionHandler:^{
            int exportStatus = _currentExportSession.status;
            switch (exportStatus) {
                case AVAssetExportSessionStatusFailed: {
                    NSLog (@"AVAssetExportSessionStatusFailed");
                    // log error to text view
                    NSString * myDescription = [NSString stringWithFormat:@"Audio export failed (AVAssetExportSessionStatusFailed)"];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    _currentExportSession = nil;
                    [AppDelegate setDefaultAudioSession];
                    [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                    break;
                }
                case AVAssetExportSessionStatusCompleted: {
                    if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted");
                    [AppDelegate setDefaultAudioSession];
                    [self.currentAttachment makeAudioAttachment: [assetURL absoluteString] anOtherURL:[_currentExportSession.outputURL absoluteString] withCompletion:^(NSError *theError) {
                        _currentExportSession = nil;
                        self.currentAttachment.humanReadableFileName = [myExportURL lastPathComponent];
                        if (self.currentAttachment.previewImage == nil) {
                            if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: makeAudioAttachment - creating preview image from db artwork");
                            // In case we fail getting the artwork from file try get artwork from Media Item
                            // However, this only displays the artwork on the upload side. The artwork is *not*
                            // included in the exported file.
                            // It should be possible to add the image using _currentExportSession.metadata. But
                            // merging with existing metadata is non trivial and we should tackle it later.
                            MPMediaItemArtwork * artwork = [song valueForProperty:MPMediaItemPropertyArtwork];
                            if (artwork != nil) {
                                if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: got artwork, creating preview image");
                                self.currentAttachment.previewImage = [artwork imageWithSize:CGSizeMake(400,400)];
                            } else {
                                if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: no artwork");
                            }
                        } else {
                            if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: artwork is in media file");
                        }
                        [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:theError];
                    }];
                    break;
                }
                case AVAssetExportSessionStatusUnknown: {
                    NSLog (@"AVAssetExportSessionStatusUnknown"); break;}
                case AVAssetExportSessionStatusExporting: {
                    NSLog (@"AVAssetExportSessionStatusExporting"); break;}
                case AVAssetExportSessionStatusCancelled: {
                    _currentExportSession = nil;
                    [self finishPickedAttachmentProcessingWithImage: nil withError:_currentExportSession.error];
                    // NSLog (@"AVAssetExportSessionStatusCancelled");
                    break;
                } 
                case AVAssetExportSessionStatusWaiting: {
                    NSLog (@"AVAssetExportSessionStatusWaiting"); break;}
                default: { NSLog (@"ERROR: AVAssetExportSessionStatusWaiting: didn't get export status"); break;}
            }
        }];
        return;
        
    } else if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        // image or movie form camera or album
        
        NSString * mediaType = attachmentInfo[UIImagePickerControllerMediaType];
                
        if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeImage)) {
            __block NSURL * myURL = attachmentInfo[UIImagePickerControllerReferenceURL];
            if (attachmentInfo[UIImagePickerControllerMediaMetadata] != nil) {
                // Image was just taken and is not yet in album
                
                
                UIImage * myOriginalImage = attachmentInfo[UIImagePickerControllerOriginalImage];
                NSURL * myFileURL = nil;
                
                // Always save a local copy. See https://github.com/hoccer/hoccer-xo-iphone/issues/211
                UIImage * myImage = [Attachment qualityAdjustedImage:myOriginalImage];
                NSString * newFileName = @"reducedSnapshotImage.jpg";
                myFileURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
                
                float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myFileURL atomically:NO];
                
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        if (myFileURL == nil) {
                            myURL = assetURL;
                        } else {
                            myURL = myFileURL;
                        }

                        // create attachment with lower quality image dependend on settings
                        [self.currentAttachment makeImageAttachment: [myURL absoluteString]
                                                         anOtherURL:nil
                                                              image: myImage
                                                     withCompletion:^(NSError *theError) {
                                                         [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:error];
                                                     }];
                    } else {
                        NSLog(@"Error saving image in Library, error = %@", error);
                        [self finishPickedAttachmentProcessingWithImage: nil withError:error];
                    }
                };
                
                // write full size full quality image to library
                if(myImage) {
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [library writeImageToSavedPhotosAlbum:[myOriginalImage CGImage]
                                              orientation:(ALAssetOrientation)[myOriginalImage imageOrientation]
                                          completionBlock:completeBlock];
                }
            } else {
                // image from album
                UIImage * myImage = attachmentInfo[UIImagePickerControllerOriginalImage];
                // Always save a local copy. See https://github.com/hoccer/hoccer-xo-iphone/issues/211
                //if ([Attachment tooLargeImage:myImage]) {
                    myImage = [Attachment qualityAdjustedImage:myImage];
                    NSString * newFileName = @"reducedSnapshotImage.jpg";
                    myURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];
                    
                    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                    [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myURL atomically:NO];
                //} else {
                //  TODO: save a local copy of the image without JPEG reencoding
                //}
                [self.currentAttachment makeImageAttachment: [myURL absoluteString]
                                                 anOtherURL:nil
                                                      image: myImage
                                             withCompletion:^(NSError *theError) {
                                                 [self finishPickedAttachmentProcessingWithImage: myImage
                                                                                       withError:theError];
                                             }];
            }
            return;
        } else if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeVideo) || [mediaType isEqualToString:@"public.movie"]) {
            NSURL * referenceURL = attachmentInfo[UIImagePickerControllerReferenceURL];
            NSURL * mediaURL = attachmentInfo[UIImagePickerControllerMediaURL];

            NSString * newFileName = @"video.mp4";
            NSURL * outputURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName];

            if (_currentExportSession != nil) {
                NSString * myDescription = [NSString stringWithFormat:@"An audio or video export is still in progress"];
                NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code:559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                return;
            }

            AVURLAsset * asset = [AVURLAsset assetWithURL:mediaURL];
            _currentExportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
            _currentExportSession.outputURL = outputURL;
            _currentExportSession.outputFileType = AVFileTypeMPEG4;
            
            [_currentExportSession exportAsynchronouslyWithCompletionHandler:^{
                if (_currentExportSession.status == AVAssetExportSessionStatusCompleted) {
                    _currentExportSession = nil;

                    if (referenceURL == nil) { // video was just recorded
                        NSString *outputFilePath = [outputURL path];

                        if ( UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputFilePath)) {
                            UISaveVideoAtPathToSavedPhotosAlbum(outputFilePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
                            NSLog(@"Saved new video at %@ to album",outputFilePath);
                        } else {
                            NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: failed to save video in album at path = %@",outputFilePath];
                            NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code:556 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                            NSLog(@"%@", myDescription);
                            [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                            return;
                        }
                    }
                    
                    NSString * outputURLString = [outputURL absoluteString];
                    self.currentAttachment.ownedURL = outputURLString;
                    
                    [self.currentAttachment makeVideoAttachment:outputURLString anOtherURL:nil withCompletion:^(NSError *theError) {
                        [self finishPickedAttachmentProcessingWithImage:self.currentAttachment.previewImage withError:theError];
                    }];
                } else {
                    [self finishPickedAttachmentProcessingWithImage:nil withError:_currentExportSession.error];
                    _currentExportSession = nil;
                }
                
                NSError * myError = nil;
                [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:&myError];

                if (myError != nil) {
                    NSLog(@"Deleting media file failed: %@", myError);
                }
            }];
            
            return;
        }
    }
    // Do not do anything here because some functions above will finish asynchronously
    // just in case, but we should never get here
    [self finishPickedAttachmentProcessingWithImage: nil withError:nil];
}
    
- (void) video: (NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo: (void *)contextInfo {
    NSLog(@"Completed: Saved new video at %@ to album, error=%@",videoPath, error);
}
    

- (void) decorateAttachmentButton:(UIImage *) theImage {
    if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"decorateAttachmentButton with %@", theImage);
    self.attachmentButton.previewImage = theImage;
}

- (void) startPickedAttachmentProcessingForObject:(id)info {
    // NSLog(@"startPickedAttachmentProcessingForObject:%@",_currentPickInfo);
    if (_currentAttachment != nil) {
        [self trashCurrentAttachment];
    }
    _currentPickInfo = info;
    [self.attachmentButton startSpinning];
    self.sendButton.enabled = NO; // wait for attachment ready
}

- (void) finishPickedAttachmentProcessingWithImage:(UIImage*) theImage withError:(NSError*) theError {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage:%@ previewIcon:%@ withError:%@",theImage, self.currentAttachment.previewIcon, theError);
        _currentPickInfo = nil;

        [self.attachmentButton stopSpinning];

        if (theError == nil && theImage != nil) {
            if (theImage.size.height == 0) {
                if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with currentAttachment.previewIcon");
                [self decorateAttachmentButton:self.currentAttachment.previewIcon];
            } else {
                if (DEBUG_ATTACHMENT_BUTTONS)NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with theImage");
                [self decorateAttachmentButton:theImage];
            }
            self.sendButton.enabled = YES;
        } else {
            if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: trashCurrentAttachment");
            [self trashCurrentAttachment];
        }
    });
}

- (void) trashCurrentAttachment {
    if (self.currentAttachment != nil) {
        if (_currentPickInfo != nil) {
            if (_currentExportSession != nil) {
                [_currentExportSession cancelExport];
                // attachment will be trashed when export session canceling will call finishPickedAttachmentProcessingWithImage
                return;
            } else {
                // NSLog(@"Picking still in progress, can't trash - or can I?");
            }
        }
        [AppDelegate.instance deleteObject:self.currentAttachment];
        //[self.managedObjectContext deleteObject: self.currentAttachment];
        self.currentAttachment = nil;
    }
    [self decorateAttachmentButton:nil];
    // TODO:
    //_attachmentButton.hidden = NO;
}

- (void) showAttachmentOptions {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"attachment_option_sheet_title", nil)
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: NSLocalizedString(@"attachment_option_remove_btn_title", nil),
                                                                  NSLocalizedString(@"attachment_option_choose_new_btn_title", nil),
                                                                  NSLocalizedString(@"attachment_option_view_btn_title", nil),
                                                                  nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet showInView: self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // NSLog(@"Clicked button at index %d", buttonIndex);
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    switch (buttonIndex) {
        case 0:
            // attachment_option_remove_btn_title pressed
            [self trashCurrentAttachment];
            break;
        case 1:
            [self.attachmentPicker showInView: self.view];
            // NSLog(@"Pick new attachment");
            break;
        case 2:
            [self presentViewForAttachment: self.currentAttachment];
            // NSLog(@"Viewing current attachment");
            break;
        default:
            break;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (DEBUG_TABLE_CELLS) NSLog(@"cellForRowAtIndexPath:%@",indexPath);
    HXOMessage * message = (HXOMessage*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    MessageCell *cell = [tableView dequeueReusableCellWithIdentifier: [self cellIdentifierForMessage: message] forIndexPath:indexPath];
    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    [self configureCell: cell forMessage: message withAttachmentPreview:YES];
    if (DEBUG_TABLE_CELLS) NSLog(@"cellForRowAtIndexPath: returning cell %@",cell);
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {

    DateSectionHeaderView * header = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier: @"date_header"];

    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    NSArray *objects = [sectionInfo objects];
    NSManagedObject *managedObject = objects[0];
    NSDate *timeSection = (NSDate *)[managedObject valueForKey:@"timeSection"];
    header.dateLabel.text = [self.dateFormatter stringFromDate: timeSection];
    return header;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 3 * kHXOGridSpacing;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // NSLog(@"tableView:didSelectRowAtIndexPath: %@",indexPath);
    HXOMessage * message = (HXOMessage*)[self.fetchedResultsController objectAtIndexPath: indexPath];

    if (message.attachment.available) {
        [self presentViewForAttachment: message.attachment];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    CGFloat myHeight = message.cachedCellHeight;
    if (myHeight != 0) {
        return myHeight;
    }

    MessageCell * cell = [_cellPrototypes objectForKey: [self cellIdentifierForMessage: message]];
    [self configureCell: cell forMessage: message withAttachmentPreview:NO];
    CGFloat height = [cell sizeThatFits: CGSizeMake(self.tableView.bounds.size.width, FLT_MAX)].height;
    message.cachedCellHeight = height;
    return height;
}

- (NSString*) cellIdentifierForMessage: (HXOMessage*) message {
    BOOL hasAttachment = message.attachment != nil;
    BOOL hasText = message.body != nil && ! [message.body isEqualToString: @""];
    if (hasAttachment && hasText) {
        return [self hasImageAttachment: message] ? [ImageAttachmentWithTextMessageCell reuseIdentifier] : [GenericAttachmentWithTextMessageCell reuseIdentifier];
    } else if (hasAttachment) {
        return [self hasImageAttachment: message] ? [ImageAttachmentMessageCell reuseIdentifier] : [GenericAttachmentMessageCell reuseIdentifier];
    } else if (hasText) {
        return [TextMessageCell reuseIdentifier];
    } else {
        NSLog(@"Error: message has neither text nor attachment");
        return [TextMessageCell reuseIdentifier]; // avoid crash in case of unreadable or empty text
    }
}

- (BOOL) hasImageAttachment: (HXOMessage*) message {
    return [message.attachment.mediaType isEqualToString: @"image"] || [message.attachment.mediaType isEqualToString: @"video"];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView == self.tableView) {
        [self hideKeyboard];
    }
}

#pragma mark - Core Data Stack


- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel == nil) {
        _managedObjectModel = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectModel;
    }
    return _managedObjectModel;
}


- (void) setPartner: (Contact*) partner {
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:setPartner %@", partner.nickName);
    // NSLog(@"%@", [NSThread callStackSymbols]);
    
    [self removeAllContactAndMembersKVOs];

    _partner = partner;
    if (partner == nil) {
        return;
    }
    [self addContactKVO: _partner];
    if ([_partner isKindOfClass: [Group class]]) {
        Group * group = (Group*) _partner;
        [group.members enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            Contact * contact = [obj contact];
            if (contact != nil) {
                [self addContactKVO: contact];
            }
        }];
        // TODO: observe membership set and add/remove KVO on new/removed members
        [self addMembersKVO:group];
    }

    if (resultsControllers == nil) {
        resultsControllers = [[NSMutableDictionary alloc] init];
    }
    if (_fetchedResultsController != nil) {
        _fetchedResultsController.delegate = nil;
    }
    _fetchedResultsController = [resultsControllers objectForKey: partner.objectID];
    if (_fetchedResultsController == nil) {
        NSDictionary * vars = @{ @"contact" : partner };
        NSFetchRequest *fetchRequest = [self.managedObjectModel fetchRequestFromTemplateWithName:@"MessagesByContact" substitutionVariables: vars];

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeAccepted" ascending: YES];
        NSArray *sortDescriptors = @[sortDescriptor];

        [fetchRequest setSortDescriptors:sortDescriptors];

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:AppDelegate.instance.mainObjectContext sectionNameKeyPath: @"timeSection" cacheName: [NSString stringWithFormat: @"Messages-%@", partner.objectID]];
        _fetchedResultsController.delegate = self;

        resultsControllers[partner.objectID] = _fetchedResultsController;

        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            [(AppDelegate *)(self.chatBackend.delegate) showCorruptedDatabaseAlert];
              return;
        }
    } else {
        _fetchedResultsController.delegate = self;
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }

    self.firstNewMessage = nil;
    [self.tableView reloadData];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scrollToRememberedCellOrToBottomIfNone];
    });
    [self configureView];
    //[self insertForwardedMessage];
}

- (void) addContactKVO: (Contact*) contact {
    if (contact != nil) {
        if (![self.observedContacts containsObject:contact]) {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addContactKVO for contact nick %@ id %@", contact.nickName, contact.clientId);
            for (id keyPath in @[@"nickName", @"avatarImage", @"connectionStatus", @"deletedObject"]) {
                if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addContactKVO for %@ path %@ id %@", [contact class], keyPath, contact.clientId);
                [contact addObserver: self forKeyPath: keyPath options: NSKeyValueObservingOptionNew context: &ChatViewObserverContext];
            }
            [self.observedContacts addObject:contact];
        } else {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addContactKVO: already has observers for contact nick %@ id %@", contact.nickName, contact.clientId);
        }
    } else {
        if (DEBUG_OBSERVERS) NSLog(@"#ERROR: ChatViewController:addContactKVO: nil contact");
    }
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addContactKVO: self.observedContacts.count = %d", self.observedContacts.count);
}

- (void) removeContactKVO: (Contact*) contact {
    if (contact != nil) {
        if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeContactKVO for contact nick %@ id %@", contact.nickName, contact.clientId);
        if ([self.observedContacts containsObject:contact]) {
            for (id keyPath in @[@"nickName", @"avatarImage", @"connectionStatus", @"deletedObject"]) {
                if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeContactKVO for %@ path %@ id %@", [contact class], keyPath, contact.clientId);
                [contact removeObserver: self forKeyPath: keyPath context: &ChatViewObserverContext];
            }
            [self.observedContacts removeObject:contact];
        } else {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeContactKVO: no observers for contact nick %@ id %@", contact.nickName, contact.clientId);
        }
    } else {
        if (DEBUG_OBSERVERS) NSLog(@"#ERROR: ChatViewController:removeContactKVO: nil contact");
    }
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeContactKVO: self.observedContacts.count = %d", self.observedContacts.count);
}

- (void) removeAllContactKVOs {
    if (DEBUG_OBSERVERS) NSLog(@"ContactSheetController: removeAllContactKVOs");
    NSSet * registered = [NSSet setWithSet:self.observedContacts]; // avoid enumeration mutation exception
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeAllContactKVOs: registered.count = %d", registered.count);
    for (Contact * contact in registered) {
        [self removeContactKVO:contact];
    }
    [self.observedContacts removeAllObjects];
}

- (void) addMembersKVO: (Group*) group {
    if (group != nil) {
        if (![self.observedMembersGroups containsObject:group]) {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addMembersKVO for group nick %@ id %@", group.nickName, group.clientId);
            [group addObserver: self forKeyPath: @"members" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: &ChatViewObserverContext];
             [self.observedMembersGroups addObject:group];
        } else {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addMembersKVO: already has observers for group nick %@ id %@", group.nickName, group.clientId);
        }
    } else {
        if (DEBUG_OBSERVERS) NSLog(@"#ERROR: ChatViewController:addMembersKVO: nil contact");
    }
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addMembersKVO: self.observedMembersGroups.count = %d", self.observedMembersGroups.count);
}

- (void) removeMembersKVO: (Group*) group {
    if (group != nil) {
        if ([self.observedMembersGroups containsObject:group]) {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeMembersKVO for group nick %@ id %@", group.nickName, group.clientId);
            [group removeObserver: self forKeyPath: @"members" context:&ChatViewObserverContext];
            [self.observedMembersGroups removeObject:group];
        } else {
            if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeMembersKVO: no observers for group nick %@ id %@", group.nickName, group.clientId);
        }
    } else {
        if (DEBUG_OBSERVERS) NSLog(@"#ERROR: ChatViewController:removeMembersKVO: nil contact");
    }
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeMembersKVO: self.observedMembersGroups.count = %d", self.observedMembersGroups.count);
}

- (void) removeAllMembersKVOs {
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController: removeAllMembersKVOs");
    NSSet * registered = [NSSet setWithSet:self.observedMembersGroups]; // avoid enumeration mutation exception
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeAllMembersKVOs: registered.count = %d", registered.count);
    for (Group * group in registered) {
        [self removeMembersKVO:group];
    }
    [self.observedMembersGroups removeAllObjects];
}

- (void) removeAllContactAndMembersKVOs {
    [self removeAllMembersKVOs];
    [self removeAllContactKVOs];
}


/*
- (void) insertForwardedMessage {
    if (self.messageToForward) {
        // NSLog(@"insertForwardedMessage");
        self.chatbar.messageField.text = self.messageToForward.body;
        
        if (self.currentAttachment) {
            [self trashCurrentAttachment];
        }
        
        AttachmentCompletionBlock completion  = ^(Attachment * myAttachment, NSError *myerror) {
            self.currentAttachment = myAttachment;
            // NSLog(@"insertForwardedMessage: self.currentAttachment=%@",self.currentAttachment);
            [self finishPickedAttachmentProcessingWithImage: myAttachment.previewImage withError:myerror];
        };
        [self.chatBackend cloneAttachment:self.messageToForward.attachment whenReady:completion];
        self.messageToForward = nil;
    }
}
*/

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    //NSLog(@"observeValueForKeyPath %@ change %@", keyPath, change);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    if ([keyPath isEqualToString: @"deletedObject"]) {
        if (DEBUG_OBSERVERS) NSLog(@"ChatViewController: observeValueForKeyPath: deletedObject");
        if ([object deletedObject]) {
            if (DEBUG_OBSERVERS) NSLog(@"DataSheetController:observeValueForKeyPath: observed deletedObject, removing observers");
            [self removeContactKVO:object];
        }
        return;
    }

    if ([keyPath isEqualToString: @"nickName"] ||
        [keyPath isEqualToString: @"connectionStatus"]) {
        // self.title = [object nickName];
        if (self.partner == object) { // single chat mode or group object change
            //self.title = [object nickNameWithStatus];
            [self configureTitle];
        } else { // group member change
            [self updateVisibleCells];
        }
    } else if ([keyPath isEqualToString: @"avatarImage"]) {
        [self updateVisibleCells];
    } else if ([keyPath isEqualToString: @"members"]) {
        if (self.partner.isGroup) {
            [self checkActionButtonVisible];
            if (self.partner.isNearby) {
                [self configureTitle];
            }
        }
        if ([change[NSKeyValueChangeKindKey] isEqualToNumber: @(NSKeyValueChangeInsertion)]) {
            // NSLog(@"==== got new group member");
            NSSet * oldMembers = change[NSKeyValueChangeOldKey];
            NSMutableSet * newMembers = [NSMutableSet setWithSet: change[NSKeyValueChangeNewKey]];
            [newMembers minusSet: oldMembers];
            [newMembers enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                [self addContactKVO: [obj contact]];
            }];
        } else if ([change[NSKeyValueChangeKindKey] isEqualToNumber: @(NSKeyValueChangeRemoval)]) {
            // NSLog(@"==== group member removed");
            NSMutableSet * removedMembers = [NSMutableSet setWithSet: change[NSKeyValueChangeOldKey]];
            NSSet * newMembers = change[NSKeyValueChangeNewKey];
            [removedMembers minusSet: newMembers];
            [removedMembers enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                [self removeContactKVO: [obj contact]];
            }];
        } else {
            //NSLog(@"ChatViewController observeValueForKeyPath: unhandled change");
        }
    } else if ([keyPath isEqualToString: @"contentSize"] && [object isEqual: self.messageField]) {
        CGRect frame = self.messageField.frame;
        frame.size.height = MIN(150, MAX( 50 - 2 * kHXOGridSpacing, self.messageField.contentSize.height));
        self.messageField.frame = frame;
        self.chatbarHeight.constant = frame.size.height + 2 * kHXOGridSpacing;
        
    } else {
        NSLog(@"ChatViewController observeValueForKeyPath: unhandled key path '%@'", keyPath);
    }
}

- (void) updateVisibleCells {
    // NSLog(@"updateVisibleCells");
    NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
    [self.tableView beginUpdates];
    for (int i = 0; i < indexPaths.count; ++i) {
        NSIndexPath * indexPath = indexPaths[i];
        HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self configureCell: (MessageCell*)[self.tableView cellForRowAtIndexPath:indexPath] forMessage: message withAttachmentPreview:YES];
    }
    [self.tableView endUpdates];
}

#pragma mark - NSFetchedResultsController delegate methods


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    //NSLog(@"controller:didChangeSection");
    switch(type) {
        case NSFetchedResultsChangeInsert:
            // NSLog(@"NSFetchedResultsChangeInsert");
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            // NSLog(@"NSFetchedResultsChangeDelete");
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    // NSLog(@"controller:didChangeObject");
    //NSLog(@"didChangeObject indexPath=%@ newIndexPath=%@", indexPath, newIndexPath);
    UITableView *tableView = self.tableView;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            //NSLog(@"NSFetchedResultsChangeInsert");
            if (self.firstNewMessage == nil) {
                self.firstNewMessage = newIndexPath;
                //NSLog(@"didChangeObject insert: set firstNewMessage indexPath=%@", newIndexPath);
            }
            break;
        case NSFetchedResultsChangeDelete:
            //NSLog(@"NSFetchedResultsChangeDelete ");
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        case NSFetchedResultsChangeUpdate:
        {
            //NSLog(@"NSFetchedResultsChangeUpdate");
            HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
            MessageCell * cell = (MessageCell*)[tableView cellForRowAtIndexPath:indexPath]; // returns nil if cell is not visible or index path is out of range
            if (cell != nil && message != nil) {
                [self configureCell: cell forMessage: message withAttachmentPreview:YES];
            }
            break;
        }

        case NSFetchedResultsChangeMove:
            //NSLog(@"NSFetchedResultsChangeMove");
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    // NSLog(@"controllerDidChangeContent");
    if (self.firstNewMessage != nil) {
        // NSLog(@"controllerDidChangeContent scroll to indexPath: %@", self.firstNewMessage);
        // [self.tableView scrollToRowAtIndexPath: self.firstNewMessage atScrollPosition: UITableViewScrollPositionBottom animated: YES];
        // [self performSelectorOnMainThread:@selector(scrollToBottomAnimatedWithObject:) withObject:@(YES) waitUntilDone:NO];
        [NSTimer scheduledTimerWithTimeInterval:0.8 target:self selector:@selector(scrollToBottomAnimated) userInfo:nil repeats:NO];
        self.firstNewMessage = nil;
    }
    [self checkActionButtonVisible];
}

#pragma mark - view/cell methods

- (void) registerCellClass: (Class) cellClass {
    [self.tableView registerClass: cellClass forCellReuseIdentifier: [cellClass reuseIdentifier]];
    MessageCell * prototype = [[cellClass alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: [cellClass reuseIdentifier]];
    //    HXOTableViewCell * prototype = [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier]];
    if (_cellPrototypes == nil) {
        _cellPrototypes = [NSMutableDictionary dictionary];
    }
    [self.cellPrototypes setObject: prototype forKey: [cellClass reuseIdentifier]];
}

- (id) getAuthor: (HXOMessage*) message {
    if (message.isOutgoing) {
        return [UserProfile sharedProfile];
    } else if ([self.partner isKindOfClass: [Group class]]) {
        return [message.deliveries.anyObject sender];
    } else {
        return self.partner;
    }
}

- (BOOL) viewIsVisible {
    return self.isViewLoaded && self.view.window;
}

- (void)configureCell:(MessageCell*)cell forMessage:(HXOMessage *) message withAttachmentPreview:(BOOL)loadPreview {
    if (cell == nil) {
        NSLog(@"#WARNING: ChatViewController:configureCell called with cell = nil");
        NSLog(@"%@", [NSThread callStackSymbols]);
        return;
    }
    if (DEBUG_TABLE_CELLS) NSLog(@"configureCell %@ withPreview=%d",cell,loadPreview);

    cell.delegate = self;

    if ([self viewIsVisible]){
        if (!message.isRead) {
            if (READ_DEBUG) NSLog(@"configureCell setting isReadFlag forMessage: %@", message.body);
            message.isRead = YES;
            [AppDelegate.instance.mainObjectContext refreshObject: message.contact mergeChanges:YES];
            Delivery * delivery = (Delivery*)message.deliveries.anyObject;
            if (message.isIncoming && delivery.isUnseen) {
                [self.chatBackend inDeliveryConfirmMessage:message withDelivery:delivery];
            }
        }
    }

    cell.colorScheme = [self colorSchemeForMessage: message];
    cell.messageDirection = message.isOutgoing ? HXOMessageDirectionOutgoing : HXOMessageDirectionIncoming;
    id author = [self getAuthor: message];
    cell.avatar.image = [author avatarImage];
    cell.avatar.defaultIcon = [[avatar_contact alloc] init];
    cell.avatar.isBlocked = [author isKindOfClass: [Contact class]] && [author isBlocked];
    cell.avatar.isPresent = [self.partner isKindOfClass: [Group class]] && ! message.isOutgoing && ((Contact*)[message.deliveries.anyObject sender]).isConnected;
    cell.avatar.isInBackground = [self.partner isKindOfClass: [Group class]] && message.isIncoming && ((Contact*)[message.deliveries.anyObject sender]).isBackground;

    cell.subtitle.text = [self subtitleForMessage: message];

    for (MessageSection * section in cell.sections) {
        if ([section isKindOfClass: [TextSection class]]) {
            [self configureTextSection: (TextSection*)section forMessage: message];
        } else if ([section isKindOfClass: [ImageAttachmentSection class]]) {
            [self configureImageAttachmentSection: (ImageAttachmentSection*)section forMessage: message withAttachmentPreview:loadPreview];
        } else if ([section isKindOfClass: [GenericAttachmentSection class]]) {
            [self configureGenericAttachmentSection: (GenericAttachmentSection*)section forMessage: message withAttachmentPreview:loadPreview];
        }
    }
}

- (void) configureTextSection: (TextSection*) section forMessage: (HXOMessage*) message {
    section.label.delegate = self;
    // maybe we find a better way to properly respond to font size changes
    //section.label.font = [UIFont systemFontOfSize: self.messageFontSize];

    section.label.attributedText = [self getItemWithMessage: message].attributedBody;
}

- (void) configureAttachmentSection: (AttachmentSection*) section forMessage: (HXOMessage*) message {
    message.attachment.progressIndicatorDelegate = self;
    [section.upDownLoadControl addTarget: self action: @selector(didToggleTransfer:) forControlEvents: UIControlEventTouchUpInside];
    [self configureUpDownLoadControl: section.upDownLoadControl attachment: message.attachment];

    section.subtitle.text = [self attachmentSubtitle: message.attachment];

}

- (void) configureUpDownLoadControl: (UpDownLoadControl*) upDownLoadControl attachment: (Attachment*) attachment{
    upDownLoadControl.hidden = attachment.available && attachment.state == kAttachmentTransfered;
    BOOL isActive = [self attachmentIsActive: attachment];
    upDownLoadControl.selected = isActive;
    if (attachment.state == kAttachmentWantsTransfer || attachment.state == kAttachmentTransferScheduled) {
        [upDownLoadControl startSpinning];
    }
}

- (void) configureGenericAttachmentSection: (GenericAttachmentSection*) section forMessage: (HXOMessage*) message withAttachmentPreview:(BOOL)loadPreview {
    [self configureAttachmentSection: section forMessage: message];

    if (loadPreview) {
        [self loadAttachmentImage: message.attachment withSection: section completion:^(Attachment * attachment, AttachmentSection * section) {
            [self finishConfigureGenericAttachmentSection:section forMessage:message withAttachmentPreview:loadPreview];
        }];
    } else {
        [self finishConfigureGenericAttachmentSection:section forMessage:message withAttachmentPreview:loadPreview];
    }

    NSString * title = message.attachment.humanReadableFileName;
    if (title == nil || [title isEqualToString: @""]) {

    }
    section.title.text = [self attachmentTitle: message];
}

- (void)finishConfigureGenericAttachmentSection: (AttachmentSection*) section forMessage: (HXOMessage*) message withAttachmentPreview:(BOOL)loadPreview {
    if ([section isKindOfClass: [GenericAttachmentSection class]]) {
        Attachment * attachment = message.attachment;
        GenericAttachmentSection * attachmentSection = (GenericAttachmentSection*)section;
        
        if (loadPreview && attachment.previewImage.size.height != 0 && attachment.state == kAttachmentTransfered) {
            attachmentSection.icon.image = attachment.previewImage;
            attachmentSection.icon.layer.cornerRadius = 0.5 * attachmentSection.icon.frame.size.width;
            attachmentSection.icon.layer.masksToBounds = YES;
        } else if (attachment.state == kAttachmentTransfered) {
            attachmentSection.icon.image = [self typeIconForAttachment: message.attachment];
            attachmentSection.icon.layer.masksToBounds = NO;
        } else {
            attachmentSection.icon.image = nil;
        }
    }
}

- (void) configureImageAttachmentSection: (ImageAttachmentSection*) section forMessage: (HXOMessage*) message withAttachmentPreview:(BOOL)loadPreview {
    if (DEBUG_TABLE_CELLS) NSLog(@"configureImageAttachmentSection %@ withPreview=%d",section,loadPreview);
    [self configureAttachmentSection: section forMessage: message];
    section.imageAspect = message.attachment.aspectRatio;

    if (loadPreview) {
        [self loadAttachmentImage: message.attachment withSection: section completion:^(Attachment * attachment, AttachmentSection * section) {
            [self finishConfigureImageAttachmentSection:section forMessage:message withAttachmentPreview:loadPreview];
        }];
    } else {
        [self finishConfigureImageAttachmentSection:section forMessage:message withAttachmentPreview:loadPreview];
    }
}

-(void)finishConfigureImageAttachmentSection:(AttachmentSection*) section forMessage: (HXOMessage*) message withAttachmentPreview:(BOOL)loadPreview {
    if (DEBUG_TABLE_CELLS) NSLog(@"finishConfigureImageAttachmentSection %@ withPreview=%d",section,loadPreview);
    if ([section isKindOfClass: [ImageAttachmentSection class]]) {
        Attachment * attachment = message.attachment;
        ImageAttachmentSection * imageSection = (ImageAttachmentSection*)section;
        if (loadPreview && attachment.previewImage.size.height != 0 && attachment.state == kAttachmentTransfered) {
            imageSection.image = message.attachment.previewImage;
        } else {
            imageSection.image = nil;
        }
        imageSection.subtitle.hidden = imageSection.image != nil;
        imageSection.showPlayButton = [attachment.mediaType isEqualToString: @"video"] && imageSection.image != nil;
    }
}

- (void) loadAttachmentImage: (Attachment*) attachment withSection: (AttachmentSection*) section completion: (AttachmentImageCompletion) completion {
    if (DEBUG_TABLE_CELLS) NSLog(@"loadAttachmentImage section %@",section);

    if (attachment.previewImage == nil && attachment.available) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [attachment loadPreviewImageIntoCacheWithCompletion:^(NSError *theError) {
                if (theError == nil) {
                    NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: attachment.message];
                    if (indexPath) {
                        if (DEBUG_TABLE_CELLS) NSLog(@"loadAttachmentImage:calling cellForRowAtIndexPath with section %@",section);
                        id cell = ((id)[self.tableView cellForRowAtIndexPath: indexPath]);
                        if (DEBUG_TABLE_CELLS) NSLog(@"loadAttachmentImage:called cellForRowAtIndexPath %@ returned cell %@",indexPath, cell);
                        if (cell) {
                            AttachmentSection * inSection = [cell attachmentSection];
                            if (DEBUG_TABLE_CELLS) NSLog(@"loadAttachmentImage: cell section = %@", inSection);
                            completion(attachment, inSection);
                            [inSection setNeedsDisplay];
                        }
                    }
                } else {
                    NSLog(@"ERROR: Failed to load attachment preview image: %@", theError);
                }
            }];
        });
    } else {
        completion(attachment, section);
    }
}

- (void) didToggleTransfer: (id) sender {
    // XXX hackish
    AttachmentSection * section = (AttachmentSection*)[sender superview];
    NSIndexPath * indexPath = [self.tableView indexPathForCell: section.cell];
    if (indexPath) {
        HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: indexPath];
        if (message && message.attachment) {
            if (message.attachment.state == kAttachmentTransfering ||
                message.attachment.state == kAttachmentWantsTransfer) {
                [message.attachment pauseTransfer];
            } else if (message.attachment.state == kAttachmentTransferOnHold) {
                if (message.isOutgoing) {
                    [message.attachment upload];
                } else {
                    [message.attachment download];
                }
            } else if (message.attachment.state == kAttachmentTransferPaused) {
                [message.attachment unpauseTransfer];
            }
            [self configureUpDownLoadControl: section.upDownLoadControl attachment: message.attachment];
        }
    }
}


- (HXOBubbleColorScheme) colorSchemeForDelivery:(Delivery*) myDelivery {
    
    if (myDelivery.isPending) {
        return HXOBubbleColorSchemeInProgress;
    } else if (myDelivery.isDelivered) {
        return HXOBubbleColorSchemeSuccess;
    } else if (myDelivery.isFailure) {
        return HXOBubbleColorSchemeFailed;
    } else {
        NSLog(@"ERROR: colorSchemeForMessage: unknown delivery state '%@'", myDelivery.state);
    }
    return HXOBubbleColorSchemeSuccess;
}


- (HXOBubbleColorScheme) colorSchemeForMessage: (HXOMessage*) message {
    
    if (message.isIncoming) {
        return HXOBubbleColorSchemeIncoming;
    }
    
    if ([message.deliveries count] == 1) {
        return [self colorSchemeForDelivery:message.deliveries.anyObject];
    } else {
        //if (message.attachment == nil) {
            // select color scheme by priority; if one message succeeded, return delivered
            NSSet * messagesDelivered = message.deliveriesDelivered;
            if (messagesDelivered.count > 0) {
                return [self colorSchemeForDelivery:messagesDelivered.anyObject];
            }

            // progress is next
            NSSet * messagesPending = message.deliveriesPending;
            if (messagesPending.count > 0) {
                return [self colorSchemeForDelivery:messagesPending.anyObject];
            }

            // only if all fail, we show failed
            NSSet * messagesFailed = message.deliveriesFailed;
            if (messagesFailed.count > 0) {
                return [self colorSchemeForDelivery:messagesFailed.anyObject];
            }
        //}
    }
    NSLog(@"ERROR: colorSchemeForMessage: strange deliveries for message id '%@', delivery count=%d", message.messageId, message.deliveries.count);
    return HXOBubbleColorSchemeSuccess;
}

NSString * delimiter(NSString* currentString) {
    if (currentString.length == 0) {
        return @"";
    } else {
        return @",";
    }
}

NSSet * intersectionOfSets(NSSet * a, NSSet * b) {
    NSMutableSet * result = [NSMutableSet setWithSet:a];
    [result intersectSet:b];
    return result;
}

NSSet * differenceOfSets(NSSet * a, NSSet * b) {
    NSMutableSet * result = [NSMutableSet setWithSet:a];
    [result minusSet:b];
    return result;
}

- (NSString*) stateStringForMessageMulti: (HXOMessage*) message {
    NSUInteger totalDeliveries = message.deliveries.count;
    
    NSSet * messagesNew;
    NSUInteger newCount = 0;
    
    NSSet * messagesDelivering;
    NSUInteger deliveringCount = 0;
    
    NSSet * messagesFailed;
    NSUInteger failedCount = 0;
    
    NSSet * messagesSeen;
    NSUInteger seenCount = 0;
    
    NSSet * messagesUnseen;
    NSUInteger unseenCount = 0;
    
    NSSet * messagesPrivate;
    NSUInteger privateCount = 0;

    NSUInteger accountedDeliveries = 0;
    
    messagesSeen = message.deliveriesSeen;
    seenCount = messagesSeen.count;
    accountedDeliveries += seenCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
    messagesUnseen = message.deliveriesUnseen;
    unseenCount = messagesUnseen.count;
    accountedDeliveries += unseenCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
    messagesPrivate = message.deliveriesPrivate;
    privateCount = messagesPrivate.count;
    accountedDeliveries += privateCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
    messagesNew = message.deliveriesNew;
    newCount = messagesNew.count;
    accountedDeliveries += newCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
    messagesDelivering = message.deliveriesDelivering;
    deliveringCount = messagesDelivering.count;
    accountedDeliveries += deliveringCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
    messagesFailed = message.deliveriesFailed;
    failedCount = messagesFailed.count;
    accountedDeliveries += failedCount;
    if (accountedDeliveries == totalDeliveries) goto ready;
    
ready:;

    NSString * info = @"";
    if (newCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), newCount, [self stateStringForDelivery:messagesNew.anyObject]]];
    }
    if (deliveringCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), deliveringCount, [self stateStringForDelivery:messagesDelivering.anyObject]]];
    }
    if (failedCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), failedCount, [self stateStringForDelivery:messagesFailed.anyObject]]];
    }
    
    if (message.attachment != nil) {
        //NSSet * attachmentsMissing = message.deliveriesAttachmentsMissing;
        //NSUInteger attachmentMissingCount = attachmentsMissing.count;
        
        NSSet * attachmentsPending = message.deliveriesAttachmentsPending;
        NSUInteger attachmentPendingCount = attachmentsPending.count;
        
        NSSet * attachmentsFailed = message.deliveriesAttachmentsFailed;
        NSUInteger attachmentFailedCount = attachmentsFailed.count;
        
        NSSet * attachmentsReceived = message.deliveriesAttachmentsReceived;
        //NSUInteger attachmentReceivedCount = attachmentsReceived.count;
        
        if (attachmentFailedCount != 0) {
            info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), attachmentFailedCount, [self stateStringForDelivery:attachmentsFailed.anyObject]]];
        }
        attachmentsPending = differenceOfSets(attachmentsPending, messagesDelivering);
        attachmentsPending = differenceOfSets(attachmentsPending, messagesNew);
        attachmentPendingCount = attachmentsPending.count;
        
        if (attachmentPendingCount != 0) {
            info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), attachmentPendingCount, [self stateStringForDelivery:attachmentsPending.anyObject]]];
        }
        messagesSeen = intersectionOfSets(messagesSeen,attachmentsReceived);
        seenCount = messagesSeen.count;
        
        messagesUnseen = intersectionOfSets(messagesUnseen,attachmentsReceived);
        unseenCount = messagesUnseen.count;
        
        messagesPrivate = intersectionOfSets(messagesPrivate,attachmentsReceived);
        privateCount = messagesPrivate.count;
    }
    if (seenCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), seenCount, [self stateStringForDelivery:messagesSeen.anyObject]]];
    }
    if (unseenCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), unseenCount, [self stateStringForDelivery:messagesUnseen.anyObject]]];
    }
    if (privateCount != 0) {
        info = [info stringByAppendingString:[NSString stringWithFormat:@"%@ %d %@", delimiter(info), privateCount, [self stateStringForDelivery:messagesPrivate.anyObject]]];
    }
    
#ifdef DEBUG
    info = [info stringByAppendingString:[NSString stringWithFormat:@" (%d)", totalDeliveries]];
#endif
    return info;
}

- (NSString*) stateStringForMessage: (HXOMessage*) message {

    if ([message.deliveries count] > 1) {
        return [self stateStringForMessageMulti:message];
    } else {
        Delivery * myDelivery = message.deliveries.anyObject;
        return [self stateStringForDelivery:myDelivery];
    }
    return @"";
}

- (NSString*) stateStringForDelivery: (Delivery*) myDelivery {
    if (myDelivery.isStateNew) {
        return NSLocalizedString(@"chat_message_pending", nil);
        
    } else if (myDelivery.isStateDelivering) {
        return NSLocalizedString(@"chat_message_sent", nil);
        
    } else if (myDelivery.isDelivered) {
        if (myDelivery.isAttachmentFailure) {
            NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", myDelivery.message.attachment.mediaType];
            NSString * stateString = [NSString stringWithFormat:NSLocalizedString(@"chat_message_delivered_failed_attachment", nil),
                                      NSLocalizedString(attachment_type, nil)];
            return stateString;
        } else  if (myDelivery.isAttachmentPending) {
            NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", myDelivery.message.attachment.mediaType];
            NSString * stateString = [NSString stringWithFormat:NSLocalizedString(@"chat_message_delivered_missing_attachment", nil),
                                      NSLocalizedString(attachment_type, nil)];
            return stateString;
        } else {
            if (myDelivery.isSeen) {
                return NSLocalizedString(@"chat_message_read", nil);
            } else if (!myDelivery.isPrivate) {
                return NSLocalizedString(@"chat_message_unread", nil);
            } else {
                return NSLocalizedString(@"chat_message_delivered", nil);
            }
        }
    } else if (myDelivery.isFailure) {
        if (myDelivery.isFailed) {
            return NSLocalizedString(@"chat_message_failed", nil);
        } else if (myDelivery.isAborted) {
            return NSLocalizedString(@"chat_message_aborted", nil);
        } else if (myDelivery.isRejected) {
            return NSLocalizedString(@"chat_message_rejected", nil);
        }
    } else {
        NSLog(@"ERROR: unknow delivery state %@", myDelivery.state);
    }
    return myDelivery.state;
}


- (NSString*) subtitleForMessage: (HXOMessage*) message {
    if (message.isOutgoing) {
        return [self stateStringForMessage: message];
    } else {
#ifdef DEBUG
        NSString * author = [[self getAuthor: message] nickName];
        NSString * attachmentMac = @"";
        if (message.attachment != nil) {
            if (message.attachment.sourceMAC != nil && message.attachment.destinationMAC != nil) {
                if ([message.attachment.sourceMAC isEqualToData:message.attachment.destinationMAC]) {
                    attachmentMac = @"[AMAC OK]";
                } else {
                    attachmentMac = @"[AMAC ERROR]";
                }
            }
        }
        if (message.sourceMAC != nil) {
            if ([message.sourceMAC isEqualToData:message.destinationMAC]) {
                return [[author stringByAppendingString:@"[MMAC OK]"] stringByAppendingString:attachmentMac];
            } else {
                return [[author stringByAppendingString:@"[MMAC ERROR]"] stringByAppendingString:attachmentMac];
            }
        }
#endif
        return [[self getAuthor: message] nickName];
    }
}

- (UIImage*) typeIconForAttachment: (Attachment*) attachment {
    NSString * iconName;
    if ([attachment.mediaType isEqualToString: @"image"]) {
        iconName = @"cnt-photo";
    } else if ([attachment.mediaType isEqualToString: @"video"]) {
        iconName = @"cnt-video";
    }  else if ([attachment.mediaType isEqualToString: @"vcard"]) {
        iconName = @"cnt-contact";
    }  else if ([attachment.mediaType isEqualToString: @"geolocation"]) {
        iconName = @"cnt-location";
    }  else if ([attachment.mediaType isEqualToString: @"audio"]) {
        NSRange findResult = [attachment.humanReadableFileName rangeOfString:@"recording"];
        if (findResult.length == @"recording".length && findResult.location == 0) {
            iconName = @"cnt-record";
        } else {
            iconName = @"cnt-music";
        }
    }  else if ([attachment.mediaType isEqualToString: @"data"]) {
        iconName = @"cnt-data";
    }
    UIImage * icon = [UIImage imageNamed: iconName];
    return [icon imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
}

- (BOOL) attachmentIsActive: (Attachment*) attachment {
    switch (attachment.state) {
        case kAttachmentTransfering:
        case kAttachmentTransferScheduled:
        case kAttachmentWantsTransfer:
            return YES;
        default:
            return NO;
    }
}

- (NSString*) attachmentTitle: (HXOMessage*) message {

    MessageItem * item = [self getItemWithMessage: message];

    Attachment * attachment = message.attachment;
    BOOL isOutgoing = message.isOutgoing;
    BOOL isComplete = [attachment.transferSize isEqualToNumber: attachment.contentSize];

    // TODO: some of this stuff is quite expensive: reading vcards, loading audio metadata, &c.
    // It is probably a good idea to cache the attachment titles in the database.
    NSString * title;
    if (isComplete || isOutgoing) {
        if ([attachment.mediaType isEqualToString: @"vcard"]) {
            title = item.vcardName;
        } else if ([attachment.mediaType isEqualToString: @"geolocation"]) {
            title = NSLocalizedString(@"attachment_type_geolocation", nil);
        } else if ([attachment.mediaType isEqualToString: @"audio"]) {
            NSRange findResult = [message.attachment.humanReadableFileName rangeOfString:@"recording"];
            if ( ! (findResult.length == @"recording".length && findResult.location == 0)) {
                title = item.audioTitle;
            }
        }
    } else if (message.attachment.state == kAttachmentTransferOnHold) {
        NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", message.attachment.mediaType];
        NSString * name = message.attachment.humanReadableFileName != nil ? message.attachment.humanReadableFileName : NSLocalizedString(attachment_type, nil);
        title = name;
    }

    if (title == nil) {
        title = attachment.humanReadableFileName;
    }
    return title;
}


- (NSString*) attachmentSubtitle: (Attachment*) attachment {

    MessageItem * item = [self getItemWithMessage: attachment.message];
    NSString * sizeString;
    long long contentSize;
    long long doneSize;
    if (attachment.incoming) {
        contentSize = [attachment.contentSize longLongValue];
        doneSize = [attachment.transferSize longLongValue];
    } else {
        contentSize = [attachment.cipheredSize longLongValue];
        doneSize = [attachment.cipherTransferSize longLongValue];
    }
    NSString * fileSize = [self.byteCountFormatter stringFromByteCount: contentSize];

    if (contentSize == doneSize) {
        sizeString = fileSize;
    } else {
        NSString * currentSize = [self.byteCountFormatter stringFromByteCount: doneSize];
        sizeString = [NSString stringWithFormat: @"%@ / %@", currentSize, fileSize];
    }

    if (attachment.state == kAttachmentTransferOnHold) {
        NSString * question = attachment.outgoing ? @"attachment_on_hold_upload_question" : @"attachment_on_hold_download_question";
        return [NSString stringWithFormat: NSLocalizedString(question, nil), fileSize];
    }

    NSString * subtitle;
    if (item.attachmentInfoLoaded) {
        if ([attachment.mediaType isEqualToString: @"vcard"]) {
            NSString * info = item.vcardEmail;
            if (! info) {
                info = item.vcardOrganization;
            }
            subtitle = info;
        } else if ([attachment.mediaType isEqualToString: @"audio"]) {
            NSString * duration = [self stringFromTimeInterval: item.audioDuration];
            if (item.audioArtist && item.audioAlbum) {
                subtitle = [NSString stringWithFormat:@"%@ – %@ – %@", item.audioArtist, item.audioAlbum, duration];
            } else if (item.audioArtist || item.audioAlbum) {
                NSString * name = item.audioAlbum ? item.audioAlbum : item.audioArtist;
                subtitle = [NSString stringWithFormat:@"%@ – %@", name, duration];
            }
        }
            
    }
    if (subtitle == nil) {
        NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", attachment.mediaType];
        NSString * name = attachment.humanReadableFileName != nil ? attachment.humanReadableFileName : NSLocalizedString(attachment_type, nil);
        subtitle = [NSString stringWithFormat: @"%@ – %@", name, sizeString];
     }
    return subtitle;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    if (hours) {
        return [NSString stringWithFormat: @"%i:%02i:%02i", hours, minutes, seconds];
    } else {
        return [NSString stringWithFormat: @"%i:%02i", minutes, seconds];
    }
}

#pragma mark - MessageViewControllerDelegate methods

-(BOOL) messageCell:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender {
    //NSLog(@"messageCell:canPerformAction:");
    if (action == @selector(deleteMessage:)) return YES;

    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    BOOL available;
    if (message.attachment != nil) {
        available = message.attachment.available;
    } else {
        available = YES;
    }
    
    if (action == @selector(copy:)) {return available;}
#ifdef DEBUG
    if (action == @selector(resendMessage:)) { return available; }
    
#endif
    if (action == @selector(forwardMessage:)) { return available; }
    
    if (action == @selector(openWithMessage:)) { return available; }
    
    if (action == @selector(shareMessage:)) { return available; }
    
    if (action == @selector(saveMessage:)) {
        if (available) {
            Attachment * myAttachment = message.attachment;
            if (myAttachment != nil) {
                if ([myAttachment.mediaType isEqualToString: @"video"] ||
                    [myAttachment.mediaType isEqualToString: @"image"]) {
                    return YES;
                }
            }
        }
        return NO;
    }
    return NO;
}

- (void) messageCell:(MessageCell *)theCell resendMessage:(id)sender {
    //NSLog(@"resendMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    for (int i = 0; i < 20;++i) {
        double delayInSeconds = 0.5 * i;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            NSString * numberedBody = [NSString stringWithFormat:@"%d:%@", i, message.body];
            [self.chatBackend forwardMessage: numberedBody toContactOrGroup:message.contact toGroupMemberOnly:nil withAttachment:message.attachment];
        });
    }
}


/*
- (void) messageCell:(MessageCell *)theCell forwardMessage:(id)sender {
    //NSLog(@"forwardMessage");
    self.messageToForward = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self.menuContainerViewController toggleRightSideMenuCompletion:^{}];
    // [self.chatBackend forwardMessage: message.body toContact:message.contact withAttachment:message.attachment];
}
 */

- (void) messageCell:(MessageCell *)theCell saveMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    Attachment * attachment = message.attachment;
    if (attachment != nil) {
        [attachment trySaveToAlbum];
    }
}

- (void) messageCell:(MessageCell *)theCell openWithMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    Attachment * attachment = message.attachment;
    if (attachment != nil) {
        [self openWithInteractionController:message];
    }
}

- (void) messageCell:(MessageCell *)theCell shareMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self openWithActivityController:message];
}

- (void) messageCell:(MessageCell *)theCell copy:(id)sender {
    // NSLog(@"copy");
    UIPasteboard * board = [UIPasteboard generalPasteboard];
    NSIndexPath * ip = [self.tableView indexPathForCell:theCell];
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: ip];
/*
    NSLog(@"ip=%@", ip);
    NSLog(@"cell=%@", theCell);
    NSLog(@"message=%@", message);
    NSLog(@"body=%@", message.body);
 */
    board.string = message.body; // always put in string first to clear board
    
    Attachment * myAttachment = message.attachment;
    if (myAttachment != nil) {
        NSURL * url1 = myAttachment.contentURL;
        NSURL * url2 = myAttachment.otherContentURL;
#if 0
        if (message.attachment.image != nil) {
            if (message.body.length > 0) {
#if 1
                NSData * myImageData = UIImagePNGRepresentation(message.attachment.image);
                NSString * myImageType = (NSString*)kUTTypePNG;
                [board addItems:@[ @{myImageType:myImageData}] ];
#else
                // TODO: find out how to put in the UIImage without converting it to data before
                NSString * myImageType = @"UIImage";
                //NSString * myImageType = (NSString*)kUTTypeImage;
                [board addItems:@[ @{myImageType:message.attachment.image}] ];
#endif
            } else {
                board.image = message.attachment.image;
            }
        }
#endif
        [message.attachment loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"attachment copy loadimage done");
            if (theImage != nil && theImage.size.height > 0) {
                board.image = theImage;
            } else {
                NSLog(@"attachment copy: Failed to get image: %@", error);
            }
            
            // put in other data even if image loading fails, but we have to wat to preserve order
            // otherwise additional board data will be wiped out when setting the image
            if (message.body.length > 0) {
                [board addItems:@[ @{(NSString*)kUTTypeUTF8PlainText:message.body}] ];
            }
            if (url1 != nil) {
                [board addItems:@[ @{@"com.hoccer.xo.url1":[url1 absoluteString]}] ];
            }
            if (url2 != nil) {
                [board addItems:@[ @{@"com.hoccer.xo.url2":[url2 absoluteString]}] ];
            }
            if (myAttachment.mediaType != nil) {
                [board addItems:@[ @{@"com.hoccer.xo.mediaType":myAttachment.mediaType}] ];
            }
            if (myAttachment.mimeType != nil) {
                [board addItems:@[ @{@"com.hoccer.xo.mimeType":myAttachment.mimeType}] ];
            }
            if (myAttachment.humanReadableFileName != nil) {
                [board addItems:@[ @{@"com.hoccer.xo.fileName":myAttachment.humanReadableFileName}] ];
            }
        }];
    }
}
- (void) messageCell:(MessageCell *)theCell deleteMessage:(id)sender {
    // NSLog(@"deleteMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self deleteMessage:message];
}

- (void) deleteMessage:(HXOMessage *) message {

    // deletion of deliveries and attachment handled by cascade deletion policies in database model
    
    [AppDelegate.instance deleteObject:message];
    [self.chatBackend.delegate saveDatabase];
    
}

- (void) messageCellDidPressAvatar:(MessageCell *)cell {
    id contact;
    if (cell.messageDirection == HXOMessageDirectionIncoming) {
        HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell: cell]];
        contact = [(Delivery*)message.deliveries.anyObject sender];
    }

    UIViewController * parent = self.navigationController.viewControllers.count > 1 ? self.navigationController.viewControllers[self.navigationController.viewControllers.count - 2] : nil;
    NSString * segueIdentifier;
    if ([parent respondsToSelector: @selector(unwindToSheetView:)] &&
        [[(id)parent inspectedObject] isEqual: contact])
    {
        // TODO: maybe use unwind segues
        //    [self.navigationController popViewControllerAnimated: YES];
        segueIdentifier = @"unwindToContact";
    } else {
        segueIdentifier = cell.messageDirection == HXOMessageDirectionIncoming ? @"showContact" : @"showProfile";
    }
    if (segueIdentifier) {
        [self performSegueWithIdentifier: segueIdentifier sender: cell];
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender: (MessageCell*) sender {
    id contactOrProfile;
    if ([segue.identifier isEqualToString: @"showProfile"]) {
        contactOrProfile = [UserProfile sharedProfile];
    } else if ([segue.identifier isEqualToString: @"showContact"]) {
        HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell: sender]];
        contactOrProfile = [(Delivery*)message.deliveries.anyObject sender];
    } else if ([segue.identifier isEqualToString: @"newGroup"]) {
        if (self.partner.isGroup) {
            // make sure before calling this segue that all group members have a relationship (friends, invited or invitedMe)
            GroupInStatuNascendi * newGroup = [GroupInStatuNascendi new];
            Group * currentGroup = (Group*)self.partner;
            [newGroup addGroupMemberContacts:currentGroup.otherMembers];
            contactOrProfile = newGroup;
        } else {
            NSLog(@"ERROR: showGroup segue on non-group-partner");
        }
    } else if ([segue.identifier isEqualToString: @"unwindToRoot"]) {
        NSLog(@"unwinding to %@", segue.destinationViewController);
    }
    if (contactOrProfile && [segue.destinationViewController respondsToSelector: @selector(setInspectedObject:)]) {
        [segue.destinationViewController setInspectedObject: contactOrProfile];
    }
}

- (void) presentViewForAttachment:(Attachment *) myAttachment {
    if ([myAttachment.mediaType isEqual: @"data"]
        || [myAttachment.mediaType isEqual: @"video"]
        // guard against old DB entries triggering https://github.com/hoccer/hoccer-xo-iphone/issues/211
        || ([myAttachment.mediaType isEqual: @"image"] && myAttachment.localURL != nil)
        //|| [myAttachment.mediaType isEqual: @"audio"]
        )
    {
        [self previewAttachment:myAttachment];
    } else  if ([myAttachment.mediaType isEqual: @"video"]) {
        // TODO: lazily allocate _moviePlayerController once
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeNone;
        _moviePlayerViewController.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"audio"]) {
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeNone;
        _moviePlayerViewController.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
        
        UIView * myView = [[UIImageView alloc] initWithImage:myAttachment.previewImage];
        
        CGRect myFrame = myView.frame;
        myFrame.size = CGSizeMake(320,320);
        myView.frame = myFrame;
        
        myView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                  UIViewAutoresizingFlexibleRightMargin |
                                  UIViewAutoresizingFlexibleTopMargin |
                                  UIViewAutoresizingFlexibleBottomMargin;
        
        //[_moviePlayerViewController.moviePlayer.view addSubview:myView];
        [_moviePlayerViewController.moviePlayer.backgroundView addSubview:myView];
        [AppDelegate setMusicAudioSession]; // TODO: set default audio session when playback has ended

        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"image"]) {
        // used with old DB entries preventing https://github.com/hoccer/hoccer-xo-iphone/issues/211
        [myAttachment loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"attachment view loadimage done");
            if (theImage != nil) {
                self.imageViewController.image = theImage;
                //[self presentViewController: self.imageViewController animated: YES completion: nil];
                [self.navigationController pushViewController: self.imageViewController animated: YES];
            } else {
                NSLog(@"image attachment view: Failed to get image: %@", error);
            }
        }];
    } else  if ([myAttachment.mediaType isEqual: @"vcard"]) {
        Vcard * myVcard = [[Vcard alloc] initWithVcardURL:myAttachment.contentURL];
        self.vcardViewController.unknownPersonViewDelegate = self;
        self.vcardViewController.displayedPerson = myVcard.person; // Assume person is already defined.
        self.vcardViewController.allowsAddingToAddressBook = YES;
        [self.navigationController pushViewController:self.vcardViewController animated:YES];
    } else  if ([myAttachment.mediaType isEqual: @"geolocation"]) {
        if (self.chatBackend.delegate.internetReachabilty.isReachable) {
            // open map viewer when online
            [myAttachment loadAttachmentDict:^(NSDictionary * geoLocation, NSError * error) {
                if (geoLocation != nil) {
                    Class mapItemClass = [MKMapItem class];
                    if (mapItemClass && [mapItemClass respondsToSelector:@selector(openMapsWithItems:launchOptions:)])
                    {
                       // Create an MKMapItem to pass to the Maps app
                        NSArray * coordinates = geoLocation[@"location"][@"coordinates"];
                        //NSLog(@"geoLocation=%@",geoLocation);
                        // NSLog(@"coordinates=%@",coordinates);
                        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([coordinates[0] doubleValue], [coordinates[1] doubleValue]);
                        MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate
                                                                       addressDictionary:nil];
                        MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
                        [mapItem setName:NSLocalizedString(@"geolocation_default_name",@"placemark name")];
                        // Pass the map item to the Maps app
                        [mapItem openInMapsWithLaunchOptions:nil];
                    }
                }
            }];
        } else {
            // open map image when offline
            [myAttachment loadImage:^(UIImage* theImage, NSError* error) {
                // NSLog(@"attachment view loadimage done");
                if (theImage != nil) {
                    self.imageViewController.image = theImage;
                    [self presentViewController: self.imageViewController animated: YES completion: nil];
                } else {
                    NSLog(@"geo attachment view: Failed to get image: %@", error);
                }
            }];
        }
    }
}

- (void) openWithInteractionController:(HXOMessage *)message {
    NSLog(@"openWithInteractionController");
    Attachment * attachment = message.attachment;
    if (attachment != nil && attachment.available) {
        NSURL * myURL = [attachment contentURL];
        NSString * uti = [Attachment UTIfromMimeType:attachment.mimeType];
        NSString * name = attachment.humanReadableFileName;
        NSLog(@"openWithInteractionController: uti=%@, name = %@", uti, name);
        self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
        self.interactionController.delegate = self;
        self.interactionController.UTI = uti;
        self.interactionController.name = name;
        [self.interactionController presentOpenInMenuFromRect:CGRectNull inView:self.view animated:YES];
    }
}

- (void) openWithActivityController:(HXOMessage *)message {
    NSLog(@"openWithActivityController");
    Attachment * attachment = message.attachment;
    
    if (attachment != nil && attachment.available) {
        
        NSMutableArray *activityItems = [[NSMutableArray alloc]init];
        
        if (message.body.length > 0) {
            [activityItems addObject:message];
        }
        if (attachment != nil) {
            [activityItems addObject:attachment];
        }
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
}

- (void) previewAttachment:(Attachment *)attachment {
    // NSLog(@"previewAttachment");
    if (attachment != nil && attachment.available) {
        NSURL * myURL = [attachment contentURL];
        NSString * uti = [Attachment UTIfromMimeType:attachment.mimeType];
        NSString * name = attachment.humanReadableFileName;
        NSLog(@"openWithInteractionController: uti=%@, name = %@ url = %@", uti, name, myURL);
        self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:myURL];
        self.interactionController.delegate = self;
        self.interactionController.UTI = uti;
        self.interactionController.name = name;
        [self.interactionController presentPreviewAnimated:YES];
    }
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController *)controller
{
	return self;
}

- (UIView *)documentInteractionControllerViewForPreview:(UIDocumentInteractionController *)controller
{
	return self.view;
}

- (CGRect)documentInteractionControllerRectForPreview:(UIDocumentInteractionController *)controller
{
	return self.view.frame;
}
- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller {
}


- (ImageViewController*) imageViewController {
    if (_imageViewController == nil) {
        _imageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    }
    return _imageViewController;
}

- (ABUnknownPersonViewController*) vcardViewController {
    if (_vcardViewController == nil) {
        _vcardViewController = [[ABUnknownPersonViewController alloc] init];;
    }
    return _vcardViewController;
}

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownPersonView didResolveToPerson:(ABRecordRef)person {
    [unknownPersonView dismissViewControllerAnimated:YES completion:nil];
}


- (void) scrollToBottomAnimated: (BOOL) animated {
    //NSLog(@"scrollToBottomAnimated %d", animated);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    if ([self.fetchedResultsController.fetchedObjects count]) {
        NSInteger lastSection = [self numberOfSectionsInTableView: self.tableView] - 1;
        NSInteger lastRow = [self tableView: self.tableView numberOfRowsInSection: lastSection] - 1;
        // NSLog(@"lastSection=%d, lastRow=%d", lastSection, lastRow);
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:  lastRow inSection: lastSection];
        // NSLog(@"scrollToBottomAnimated indexPath=%@ ", indexPath);
        [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionBottom animated: animated];
    }
    
}

- (void) scrollToBottomAnimatedWithObject:(id)theObject {
    [self scrollToBottomAnimated: theObject != nil];
}

- (void) scrollToBottomAnimated {
    [self scrollToBottomAnimated: YES];
}

- (void) rememberLastVisibleCell {
    //    NSLog(@"rememberLastVisibleCell");
    // save index path of bottom most visible cell
    NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
    self.partner.rememberedLastVisibleChatCell = [indexPaths lastObject];
    // NSLog(@"rememberLastVisibleCell = %@",self.partner.rememberedLastVisibleChatCell);
}

- (BOOL)isValidIndexPath:(NSIndexPath*)thePath {
    if (thePath == nil) {
        return NO;
    }
    return thePath.section < [self.tableView numberOfSections] && thePath.row < [self.tableView numberOfRowsInSection:thePath.section];
}

- (void) scrollToCell:(NSIndexPath*)theCell {
    //NSLog(@"scrollToCell %@", theCell);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    [self.tableView scrollToRowAtIndexPath: self.partner.rememberedLastVisibleChatCell atScrollPosition:UITableViewScrollPositionBottom animated: NO];
}

- (void) scrollToRememberedCellOrToBottomIfNone {
    if ([self isValidIndexPath:self.partner.rememberedLastVisibleChatCell]) {
        [self scrollToCell:self.partner.rememberedLastVisibleChatCell];
    } else {
        [self scrollToBottomAnimated];
    }
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self rememberLastVisibleCell];
  }
- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // NSLog(@"didRotateFromInterfaceOrientation:%d, (not) reloading data",fromInterfaceOrientation);

    [self scrollToRememberedCellOrToBottomIfNone];
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self removeContactKVO: self.partner];
    if ([self.partner isKindOfClass: [Group class]]) {
        Group * group = (Group*) self.partner;
        [group.members enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            Contact * contact = [obj contact];
            if (contact != nil) {
                [self removeContactKVO: contact];
            }
        }];
        [self removeMembersKVO:group];
    }
    [self.messageField removeObserver: self forKeyPath: @"contentSize"];
}

#pragma mark - Link Highlighing and Handling

- (void) hyperLabel:(HXOHyperLabel *)label didPressLink: (NSTextCheckingResult*) link long:(BOOL)longPress {
    switch (link.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"tapped link %@ long: %d", link.URL, longPress);
            [[UIApplication sharedApplication] openURL: link.URL];
            break;
        case NSTextCheckingTypePhoneNumber:
            NSLog(@"tapped phone number %@ long: %d", link.phoneNumber, longPress);
            [self makePhoneCall: link.phoneNumber];
            break;
        default:
            NSLog(@"tapped unhandled link");
    }
}

- (void) makePhoneCall: (NSString*) phoneNumber {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: phoneNumber
                                                     message: nil
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 if (buttonIndex != alertView.cancelButtonIndex) {
                                                     NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [phoneNumber stringByReplacingOccurrencesOfString:@" " withString:@"-"]]];
                                                     [[UIApplication sharedApplication] openURL: url];
                                                 }
                                             }
                                           cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                           otherButtonTitles: NSLocalizedString(@"chat_call_phone_number_btn_title", nil), nil];
    [alert show];
}

- (AttachmentSection*) getSectionForAttachment: (Attachment*) attachment {
    NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: attachment.message];
    if (indexPath) {
        return ((id<AttachmentMessageCell>)[self.tableView cellForRowAtIndexPath: indexPath]).attachmentSection;
    } else {
        attachment.progressIndicatorDelegate = nil;
    }
    return nil;
}

- (void) attachmentTransferScheduled: (Attachment*) attachment {
    AttachmentSection * section = [self getSectionForAttachment: attachment];
    if (section) {
        [self configureUpDownLoadControl: section.upDownLoadControl attachment: attachment];
        section.subtitle.text = [self attachmentSubtitle: attachment];
    }
}

- (void) attachmentTransferStarted:(Attachment *)attachment {
    AttachmentSection * section = [self getSectionForAttachment: attachment];
    if (section) {
        [self configureUpDownLoadControl: section.upDownLoadControl attachment: attachment];
        section.subtitle.text = [self attachmentSubtitle: attachment];
    }
}

- (void) attachmentTransferFinished:(Attachment *)attachment {
    AttachmentSection * section = [self getSectionForAttachment: attachment];
    if (section) {
        [self configureUpDownLoadControl: section.upDownLoadControl attachment: attachment];
        section.subtitle.text = [self attachmentSubtitle: attachment];
    }

}

- (void) attachment:(Attachment *)attachment transferDidProgress:(float)theProgress {
    AttachmentSection * section = [self getSectionForAttachment: attachment];
    if (section) {
        section.upDownLoadControl.progress = theProgress;
        section.subtitle.text = [self attachmentSubtitle: attachment];
    }
}

- (Contact*) inspectedObject {
    return self.partner;
}

- (void) setInspectedObject:(Contact *)inspectedObject {
    if (self.inspectedObject != nil) {
        [AppDelegate.instance endInspecting:self.inspectedObject withInspector:self];
    }
    self.partner = inspectedObject;
    if (self.inspectedObject != nil) {
        [AppDelegate.instance beginInspecting:self.inspectedObject withInspector:self];
    }
}

@end
