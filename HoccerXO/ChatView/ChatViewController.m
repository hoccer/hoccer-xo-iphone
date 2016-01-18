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
#import <AVFoundation/AVMetadataItem.h>

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
#import "AudioAttachmentMessageCell.h"
#import "GenericAttachmentMessageCell.h"
#import "ImageAttachmentWithTextMessageCell.h"
#import "AudioAttachmentWithTextMessageCell.h"
#import "GenericAttachmentWithTextMessageCell.h"
#import "TextSection.h"
#import "ImageAttachmentSection.h"
#import "AudioAttachmentSection.h"
#import "GenericAttachmentSection.h"
#import "LabelWithLED.h"
#import "UpDownLoadControl.h"
#import "DateSectionHeaderView.h"
#import "MessageItem.h"
#import "AttachmentInfo.h"
#import "HXOHyperLabel.h"
#import "paper_dart.h"
#import "paper_clip.h"
#import "HXOUI.h"
#import "AvatarView.h"
#import "avatar_contact.h"
#import "AttachmentButton.h"
#import "GroupInStatuNascendi.h"
#import "HXOPluralocalization.h"
#import "HXOAudioPlaybackButtonController.h"
#import "NSString+FromTimeInterval.h"

#define DEBUG_ATTACHMENT_BUTTONS    NO
#define DEBUG_TABLE_CELLS           NO
#define DEBUG_NOTIFICATIONS         NO
#define DEBUG_APPEAR                NO
#define READ_DEBUG                  NO
#define DEBUG_OBSERVERS             NO
#define DEBUG_CELL_HEIGHT_CACHING   NO
#define DEBUG_MULTI_EXPORT          NO
#define DEBUG_ROTATION              NO
#define DEBUG_ATTACHMENT_STORE      NO

static const NSUInteger kMaxMessageBytes = 10000;
static const NSTimeInterval kTypingTimerInterval = 3;

static int ChatViewObserverContext = 0;

typedef void(^AttachmentImageCompletion)(Attachment*, AttachmentSection*);

@interface ChatViewController () {
    UIBackgroundTaskIdentifier _backgroundTaskId;
}
@property (nonatomic, strong)   UIPopoverController            * masterPopoverController;
@property (nonatomic, readonly) AttachmentPickerController     * attachmentPicker;
//@property (nonatomic, strong)   UIView                         * attachmentPreview;
@property (nonatomic, strong)   NSIndexPath                    * firstNewMessage;
@property (nonatomic, strong)   NSMutableDictionary            * cellPrototypes;
//@property (nonatomic, readonly) ImageViewController            * imageViewController;
//@property (nonatomic, readonly) ABUnknownPersonViewController  * vcardViewController;
@property (nonatomic, strong)   LabelWithLED                   * titleLabel;

@property (strong, nonatomic)   HXOMessage                     * messageToForward;

@property (nonatomic, readonly) NSMutableDictionary            * messageItems;
@property (nonatomic, readonly) NSDateFormatter                * dateFormatter;
@property (nonatomic, readonly) NSByteCountFormatter           * byteCountFormatter;

@property (nonatomic, strong)   UITextField                    * autoCorrectTriggerHelper;
@property (nonatomic, strong)   UILabel                        * messageFieldPlaceholder;
@property (nonatomic, strong)   NSTimer                        * typingTimer;

@property  BOOL                                                keyboardShown;
@property  BOOL                                                pickingAttachment;
@property  BOOL                                                hasPickedAttachment;
@property  BOOL                                                startAttachmentSpinnerWhenViewAppears; // Fuck you, Apple!

@property (strong) UIBarButtonItem * actionButton;

@property (strong) id throwObserver;
@property (strong) id catchObserver;
@property (strong) id loginObserver;

@property (nonatomic, readonly) NSMutableSet * observedContacts;
@property (nonatomic, readonly) NSMutableSet * observedMembersGroups;

@property (nonatomic, strong) ALAssetsLibrary * assetLibrary;


@end


@implementation ChatViewController

//@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;

@synthesize moviePlayerViewController = _moviePlayerViewController;
@synthesize imageViewController = _imageViewController;
@synthesize vcardViewController = _vcardViewController;
@synthesize interactionController = _interactionController;

@synthesize currentExportSession = _currentExportSession;
@synthesize currentMultiExportSession = _currentMultiExportSession;
@synthesize currentPickInfo = _currentPickInfo;
@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize messageItems = _messageItems;
@synthesize dateFormatter = _dateFormatter;
@synthesize byteCountFormatter = _byteCountFormatter;
@synthesize observedContacts = _observedContacts;
@synthesize observedMembersGroups = _observedMembersGroups;
@synthesize multiAttachmentExportItems = _multiAttachmentExportItems;
@synthesize assetLibrary = _assetLibrary;

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

-(ALAssetsLibrary*)assetLibrary {
    if (_assetLibrary == nil) {
        _assetLibrary = [[ALAssetsLibrary alloc] init];
    }
    return _assetLibrary;
}

- (void) registerBackgroundTask {
    NSLog(@"ChatViewController: registering background task...");
    [AppDelegate.instance startedBackgroundTask];
    if (_backgroundTaskId != UIBackgroundTaskInvalid) {
        NSLog(@"#WARNING: ChatViewController: trying to registering background task while one is already registered");
    }
    UIApplication *app = [UIApplication sharedApplication];
    _backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler: ^{
        // do cleanup here
        NSLog(@"### ChatViewController: running background task expiration handler...");
        [AppDelegate.instance finishedBackgroundTask];
        [app endBackgroundTask:_backgroundTaskId];
        _backgroundTaskId = UIBackgroundTaskInvalid;
    }];
}

- (void) unregisterBackgroundTask {
    NSLog(@"ChatViewController: unregistering background task...");
    UIApplication *app = [UIApplication sharedApplication];
    [app endBackgroundTask:_backgroundTaskId];
    _backgroundTaskId = UIBackgroundTaskInvalid;
    [AppDelegate.instance finishedBackgroundTask];
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
    [self registerCellClass: [AudioAttachmentMessageCell class]];
    [self registerCellClass: [GenericAttachmentMessageCell class]];
    [self registerCellClass: [ImageAttachmentWithTextMessageCell class]];
    [self registerCellClass: [AudioAttachmentWithTextMessageCell class]];
    [self registerCellClass: [GenericAttachmentWithTextMessageCell class]];
    [self.tableView registerClass: [DateSectionHeaderView class] forHeaderFooterViewReuseIdentifier: @"date_header"];

    self.titleLabel = [[LabelWithLED alloc] init];
    self.navigationItem.titleView = self.titleLabel;
    self.titleLabel.textColor = [[HXOUI theme] navigationBarTextColor];
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

    //UIImage * icon = [[paper_clip alloc] init].image;
    self.attachmentButton = [[AttachmentButton alloc] initWithFrame: CGRectMake(0, 0, s, s)];
    self.attachmentButton.frame = CGRectMake(0, 0, 50, s);
    self.attachmentButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.attachmentButton.tintColor = [HXOUI theme].tintColor;
    self.attachmentButton.accessibilityFrame = self.attachmentButton.frame;
    self.attachmentButton.accessibilityLabel = NSLocalizedString(@"accessibiltiy_select_attachment", nil);
    [self.attachmentButton addTarget: self action:@selector(attachmentPressed:) forControlEvents: UIControlEventTouchUpInside];
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
    self.messageField.accessibilityFrame = self.messageField.frame;


    CGRect frame = CGRectInset(self.messageField.frame, 5, 1); // experimentally found... :-/
    self.messageFieldPlaceholder = [[UILabel alloc] initWithFrame: frame];
    self.messageFieldPlaceholder.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.messageFieldPlaceholder.font = self.messageField.font;
    self.messageFieldPlaceholder.textColor = [HXOUI theme].lightTextColor;
    self.messageFieldPlaceholder.text = NSLocalizedString(@"chat_message_placeholder", nil);
    [self.chatbar addSubview: self.messageFieldPlaceholder];

    UIImage * icon = [[paper_dart alloc] init].image;
    self.sendButton = [UIButton buttonWithType: UIButtonTypeSystem];
    self.sendButton.frame = CGRectMake(CGRectGetMaxX(self.messageField.frame), 0, s, s);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    self.sendButton.accessibilityLabel = NSLocalizedString(@"accessibiltiy_send_message", nil);
    [self.sendButton setImage: icon forState: UIControlStateNormal];
    [self.sendButton addTarget: self action:@selector(sendPressed:) forControlEvents: UIControlEventTouchUpInside];
    [self.chatbar addSubview: self.sendButton];
    
    self.attachmentExportProgress = [[UILabel alloc] initWithFrame:CGRectMake(2, 2, 2*kHXOGridSpacing, 2*kHXOGridSpacing)];
    self.attachmentExportProgress.hidden = YES;
    self.attachmentExportProgress.backgroundColor = [HXOUI theme].tintColor;
    self.attachmentExportProgress.textColor = [HXOUI theme].navigationBarBackgroundColor;
    self.attachmentExportProgress.textAlignment = NSTextAlignmentCenter;
    self.attachmentExportProgress.layer.masksToBounds = YES;
    self.attachmentExportProgress.layer.cornerRadius = kHXOGridSpacing;
    [self.chatbar addSubview: self.attachmentExportProgress];
    
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
    [self restoreTypedBody];
    if (DEBUG_APPEAR) NSLog(@"ChatViewController:viewWillAppear: self.pickingAttachment=%d, self.hasPickedAttachment =%d", self.pickingAttachment, self.hasPickedAttachment);
    if (!self.pickingAttachment && !self.hasPickedAttachment) {
        [self restoreAttachments];
    } else {
        self.pickingAttachment = NO;
        self.hasPickedAttachment = NO;
    }
    
    [AppDelegate setWhiteFontStatusbarForViewController:self];

    NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
    self.throwObserver = [nc addObserverForName:@"gesturesInterpreterDidDetectThrow"
                                         object:nil
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: Throw");
                                         if (self.sendButton.enabled) {
                                             [self sendPressed:nil];
                                         }
                                     }];

    self.catchObserver = [nc addObserverForName:@"gesturesInterpreterDidDetectCatch"
                                         object:nil
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: Catch");
                                     }];
    self.loginObserver = [nc addObserverForName:@"loginSucceeded"
                                         object:nil
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
                                         if (DEBUG_NOTIFICATIONS) NSLog(@"ChatView: loginSucceeded");
                                         if (!AppDelegate.instance.runningInBackground) {
                                             if (self.partner.isNearby) {
                                                 [AppDelegate.instance configureForMode:ACTIVATION_MODE_NEARBY];
                                             } else if (self.partner.isWorldwide) {
                                                 [AppDelegate.instance configureForMode:ACTIVATION_MODE_WORLDWIDE];
                                             } else {
                                                 [AppDelegate.instance configureForMode:ACTIVATION_MODE_NONE];
                                             }
                                             if (AppDelegate.instance.unreadMessageCount > 0) {
                                                 // in case we have received messages in the background, we need to properly
                                                 // handle read message handling
                                                 [self.tableView reloadData];
                                             }
                                         }
                                     }];

    if (self.startAttachmentSpinnerWhenViewAppears) {
        // Due to some "optizations" introduced in iOS9, animations will not run when started earlier
        [self.attachmentButton startSpinning];
        self.startAttachmentSpinnerWhenViewAppears = NO;
    }

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

-(void)rememberTypedBody {

    if ([self.messageField isFirstResponder]) {
        [self.autoCorrectTriggerHelper becomeFirstResponder]; // trigger autocompletion on last word ...
        [self.messageField becomeFirstResponder];     // ... without hiding the keyboard
    }
    self.partner.savedMessageBody = self.messageField.text;
}

-(void)restoreTypedBody {
    self.messageField.text = self.partner.savedMessageBody;
    if (self.messageField.text.length > 0) {
        [self.messageField becomeFirstResponder];
    }
    [self textViewDidChange: self.messageField];
}

+(NSDictionary*)encodeMultiAttachments:(NSArray*)multiAttachments {
    NSMutableDictionary * result = [NSMutableDictionary new];
    for (id element in multiAttachments) {
        
        if ([element isKindOfClass:[MPMediaItem class]]) {
            MPMediaItem * item = element;
            NSNumber * persistentId = [NSNumber numberWithUnsignedLong:item.persistentID];
            result[persistentId] = @"MPMediaItem";

        } else if ([element isKindOfClass:[ALAsset class]]) {
            ALAsset * asset = element;
            NSURL * url = [asset valueForProperty:ALAssetPropertyAssetURL];
            result[url] = @"ALAsset";
            
        } else {
            NSLog(@"#ERROR: unknown item in multiAttachments:%@", element);
        }
    }
    
    return result;
}

+(MPMediaItem*)mediaItemForId:(NSNumber*)myPersistentId {
    MPMediaItem *song;
    MPMediaPropertyPredicate *predicate;
    MPMediaQuery *songQuery;
    
    predicate = [MPMediaPropertyPredicate predicateWithValue: myPersistentId forProperty:MPMediaItemPropertyPersistentID comparisonType:MPMediaPredicateComparisonEqualTo];
    songQuery = [[MPMediaQuery alloc] init];
    [songQuery addFilterPredicate: predicate];
    if (songQuery.items.count > 0)
    {
        //song exists
        song = [songQuery.items objectAtIndex:0];
        return song;
        //CellDetailLabel = [CellDetailLabel stringByAppendingString:[song valueForProperty: MPMediaItemPropertyTitle]];
    }
    return nil;
}

-(void)compactAttachments:(NSArray*)sparseArray whenFinished:(ArrayCompletionBlock)onReady {
    NSMutableArray * result = [NSMutableArray new];
    for (id element in sparseArray) {
        if (![element isKindOfClass:[NSNull class]]) {
            [result addObject:element];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        onReady(result);
    });
}

// Recreate an array of ALAAsset and MPMediaItem from a dictionary
// This is a bit complicated as the assetlibrary works asynchronously,
// so we have to gather stuff first in an intermediate array
// and remove potentially failed conversions
-(void)decodeMultiAttachments:(NSDictionary*)dictionary whenFinished:(ArrayCompletionBlock)onReady {
    
    NSMutableArray * interMediateResult = [NSMutableArray new];

    //ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];

    int i = 0;
    __block int done = 0;
    for (id key in dictionary) {
        [interMediateResult addObject:[NSNull new]];
        NSString * className = dictionary[key];
        if ([@"MPMediaItem" isEqualToString:className]) {
            NSNumber * persistentId = key;
            MPMediaItem * song = [ChatViewController mediaItemForId:persistentId];
            if (song) {
                [interMediateResult setObject:song atIndexedSubscript:i];
            }
            ++done;
            
        } else if ([@"ALAsset" isEqualToString:className]) {
            NSURL * url = key;
            [self.assetLibrary assetForURL:url resultBlock:^(ALAsset *asset) {
                [interMediateResult setObject:asset atIndexedSubscript:i];
                if (++done == dictionary.count) {
                    [self compactAttachments:interMediateResult whenFinished:onReady];
                }
            } failureBlock:^(NSError *error) {
                NSLog(@"#WARNING: url %@ in multiAttachments not found in assets, error=%@", url, error);
                if (++done == dictionary.count) {
                    [self compactAttachments:interMediateResult whenFinished:onReady];
                }
            }];
        } else {
            NSLog(@"#ERROR: unknown className in multiAttachments:%@", className);
        }
        ++i;
    }
    if (done == dictionary.count) {
        [self compactAttachments:interMediateResult whenFinished:onReady];
    }
}


-(void)rememberAttachments {
    if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:rememberAttachments");
    
    if (self.currentAttachment != nil) {
        if (_currentPickInfo != nil) {
            if (_currentExportSession != nil) {
                [_currentExportSession cancelExport];
                if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:rememberAttachments: cancel export");
                // attachment will be trashed when export session canceling will call finishPickedAttachmentProcessingWithImage
                return;
            } else {
                // NSLog(@"Picking still in progress, can't trash - or can I?");
            }
        } else {
            // there is a picked and exported attachment to remember
            self.partner.savedAttachment = self.currentAttachment;
            if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:rememberAttachments: saved current attachments");
        }
        self.currentAttachment = nil;
        self.hasPickedAttachment = NO;

    } else if (self.currentMultiAttachment != nil) {
        NSDictionary * savedAttachmentsDict = [ChatViewController encodeMultiAttachments:self.currentMultiAttachment];
        self.partner.savedAttachments = savedAttachmentsDict;
        if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:rememberAttachments: saved current multi-attachments");
        self.currentMultiAttachment = nil;
    }
    [self decorateAttachmentButton:nil];
    [AppDelegate.instance saveDatabase];
    // TODO:
    //_attachmentButton.hidden = NO;
}

-(void)restoreAttachments {
    
    if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:restoreAttachments, saved = %@, multi = %@", self.partner.savedAttachment, self.partner.savedAttachments);
    
    if (self.partner.savedAttachment != nil) {
        self.currentAttachment = self.partner.savedAttachment;
        self.partner.savedAttachment = nil;
        [AppDelegate.instance saveDatabase];
        if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:restoreAttachments : restored");
        [self.currentAttachment ensurePreviewImageWithCompletion:^(NSError *theError) {
            if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:restoreAttachments : finishing picking");
            [self finishPickedAttachmentProcessingWithImage:self.currentAttachment.previewImage withError:theError];
            if (theError != nil) {
                NSLog(@"Failed to load preview for saved attachment, trashing %@, error = %@", self.currentAttachment, theError);
            }
        }];
    } else if (self.partner.savedAttachments != nil) {
        [self decodeMultiAttachments:self.partner.savedAttachments whenFinished:^(NSArray *result) {
            self.currentMultiAttachment = result;
            self.partner.savedAttachments = nil;
            UIImage * preview = [ChatViewController createMultiAttachmentPreview:self.currentMultiAttachment];
            [self finishPickedAttachmentProcessingWithImage:preview withError:nil];
        }];
    } else {
        if (DEBUG_ATTACHMENT_STORE) NSLog(@"ChatViewController:restoreAttachments : decorating attachment button with nil");
        [self decorateAttachmentButton:nil];
    }
}


- (void) viewWillDisappear:(BOOL)animated {
    if (DEBUG_APPEAR) NSLog(@"ChatViewController:viewWillDisappear");
    
    [self rememberLastVisibleCell];
    [self rememberTypedBody];
    if (!self.pickingAttachment) {
        [self rememberAttachments];
    }
    
    if (self.throwObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.throwObserver];
    }
    if (self.catchObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.catchObserver];
    }
    if (self.loginObserver != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.loginObserver];
    }
    [super viewWillDisappear:animated];
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
    Contact * partner = self.partner;
    if (partner != nil) {
        NSString * label = partner.nickNameWithStatus;
        // NSLog(@"setting title to %@", label);
        self.titleLabel.text = label;
        self.titleLabel.ledOn = partner.isConnected;
        self.titleLabel.ledColor = partner.isBackground ? HXOUI.theme.avatarOnlineInBackgroundLedColor : HXOUI.theme.avatarOnlineLedColor;
    }
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
        for (id section in [_cellPrototypes[key] sections]) {
            if ([section respondsToSelector: @selector(preferredContentSizeChanged:)]) {
                [section preferredContentSizeChanged: notification];
            }
        }
    }
    self.messageField.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    self.messageFieldPlaceholder.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    [self updateVisibleCells];
    if (SYSTEM_VERSION_LESS_THAN(@"8.0")) {
        [self.tableView reloadData];
    }
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
    BOOL flipped = UIInterfaceOrientationIsLandscape(orientation) && SYSTEM_VERSION_LESS_THAN(@"8.0");
    CGFloat height = flipped ? keyboardFrame.size.width : keyboardFrame.size.height;
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
    [self.chatBackend changePresenceToNormal];
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
            NSArray * ids = permanentObjectIds(messages);
            if (ids != nil) {
                [AppDelegate.instance performWithoutLockingInNewBackgroundContext:^(NSManagedObjectContext *context) {
                    NSArray * messages = existingManagedObjects(ids, context);
                    if (messages) {
                        for (HXOMessage * message in messages) {
                            [AppDelegate.instance deleteObject:message inContext:context];
                        }
                    } else {
                        NSLog(@"#ERROR: askDeleteMessages: one or more messages to delete are already gone, not deleting anything");
                    }
                }];
            } else {
                NSLog(@"#ERROR: askDeleteMessages: could not obtain permanent object ids for some messages, not deleting anything");
            }
        }
    };
    
    NSString * title = [NSString stringWithFormat:HXOPluralocalizedString(@"chat_messages_delete_safety_question %d", messages.count, NO), messages.count];
    
    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: title
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [sheet showInView: self.view];
    });
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

// Hmmmk... Since Objective-C got array literals variadic functions are even more
// unattractive than before. I think we should wrap the variadics and provide versions
// that just use arrays... someday [agnat]

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
        // TODO: worldwide
        [buttonTitles addObject: NSLocalizedString(group.isNearby ?  @"chat_group_clone_nearby" : group.isWorldwide ? @"chat_group_clone_nearby" : @"chat_group_clone", nil)];
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
                } else if (group.isWorldwide) {
                    messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_worldwide_group_you_are_alone_message", nil)];
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
        } else if (self.partner.isNearby || self.partner.isWorldwide) {
            if (self.partner.isNearby && !self.partner.isPresent && !self.partner.isBackground) {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_nearby_contact_offline", nil)];
            } else if (self.partner.isSuspendedWorldwideContact) {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"chat_worldwide_contact_offline", nil)];
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
        
        // allow only no attachment or valid attachment
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

-(NSURL*) acquireAndReserveFileUrlFor:(NSString*)newFileName isTemporary:(BOOL)isTemporary {
    NSURL * myURL = nil;
    @synchronized(self) {
        myURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:isTemporary];
        NSError * error = nil;
        //[@"" writeToURL:myURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
        if (error != nil) {
            NSLog(@"reallySendMessage: could not write to %@, error = %@", myURL, error);
            return nil;
        }
        return myURL;
    }
}

-(NSString *) videoQualityPreset {
    NSInteger videoQuality = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"videoQuality"] integerValue];
    switch (videoQuality) {
        case UIImagePickerControllerQualityTypeHigh: return AVAssetExportPresetHighestQuality;
        case UIImagePickerControllerQualityTypeMedium: return AVAssetExportPresetMediumQuality;
        case UIImagePickerControllerQualityTypeLow: return AVAssetExportPresetLowQuality;
        case UIImagePickerControllerQualityType640x480: return AVAssetExportPreset640x480;
        case UIImagePickerControllerQualityTypeIFrame1280x720: return AVAssetExportPreset1280x720;
        case UIImagePickerControllerQualityTypeIFrame960x540: return AVAssetExportPreset960x540;
        default: return AVAssetExportPresetPassthrough;
    }
}

-(void)updateMultiAttachmentExportProgress {
    NSLog(@"updateMultiAttachmentExportProgress: items = %lu", (unsigned long)
          self.multiAttachmentExportItems.count);
    self.attachmentExportProgress.hidden = self.multiAttachmentExportItems == nil;
    self.attachmentExportProgress.text = [NSString stringWithFormat:@"%@", @(self.multiAttachmentExportItems.count)];
}


-(void)exportAndSendMultiAttachmentsToContactOrGroup:(Contact*)contact {
    // TODO: communicate exported items failures to user
    if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: items = %lu", (unsigned long)self.multiAttachmentExportItems.count);
    if (self.multiAttachmentExportItems.count == 0) {
        if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: ready");
        self.multiAttachmentExportItems = nil;
        [self updateMultiAttachmentExportProgress];
        [self unregisterBackgroundTask];
        [AppDelegate.instance resumeDocumentMonitoring];
    } else {
        
        id mediaItemOrPartner = self.multiAttachmentExportItems[0];
        self.multiAttachmentExportItems = [self.multiAttachmentExportItems subarrayWithRange:NSMakeRange(1, self.multiAttachmentExportItems.count-1)];
        
        if ([mediaItemOrPartner isKindOfClass:[Contact class]]) {
            if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: changed partner to %@", contact.nickName);
            Contact* contact = mediaItemOrPartner;
            [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
            return;
        }
        [self updateMultiAttachmentExportProgress];
        
        double delayInSeconds = 0.5;
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {

            if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: dispatched on main queue");

            NSManagedObjectContext * context = [AppDelegate.instance currentObjectContext];
            Attachment * attachment =  (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                                  inManagedObjectContext: context];
            
            if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: inserted new attachment");
            if ([mediaItemOrPartner isKindOfClass:[MPMediaItem class]]) {
                
                MPMediaItem * item = mediaItemOrPartner;
                
                //[self registerBackgroundTask];
                if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: calling didPickMPMediaAttachment");
                [self didPickMPMediaAttachment:item into:attachment inSession:&_currentMultiExportSession withCompletion:^(UIImage *image, NSError *error) {
                    if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: didPickMPMediaAttachment returned with image %@ error %@", image, error);
                    if (error == nil) {
                        if (attachment.contentSize > 0) {
                            [self.chatBackend sendMessage:@"" toContactOrGroup:contact toGroupMemberOnly:nil withAttachment:attachment withCompletion:^(NSError *theError) {
                                //[self unregisterBackgroundTask];
                                [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                            }];
                        } else {
                            NSLog(@"#ERROR: media export error: contentSize is 0, attachment=%@", attachment);
                            [attachment performSafeDeletion];
                            //[AppDelegate.instance deleteObject:attachment];
                            //[self unregisterBackgroundTask];
                            [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                        }
                    } else {
                        NSLog(@"#ERROR: media export failed, error: %@, attachment=%@", error, attachment);
                        [attachment performSafeDeletion];
                        //[AppDelegate.instance deleteObject:attachment];
                        //[self unregisterBackgroundTask];
                        [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                    }
                }];
                
            } else if ([mediaItemOrPartner isKindOfClass:[ALAsset class]]) {
                ALAsset * asset = mediaItemOrPartner;
                
                if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: calling exportALAsset");
                //[self registerBackgroundTask];
                [self exportALAsset:asset intoAttachment:attachment onCompletion:^(NSError *theError) {
                    if (DEBUG_MULTI_EXPORT) NSLog(@"exportAndSendMultiAttachmentsToContactOrGroup: exportALAsset returned with error %@", theError);
                    if (theError == nil) {
                        if (attachment.contentSize > 0) {
                            [self.chatBackend sendMessage:@"" toContactOrGroup:contact toGroupMemberOnly:nil withAttachment:attachment withCompletion:^(NSError *theError) {
                                //[self unregisterBackgroundTask];
                                [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                            }];
                        } else {
                            NSLog(@"#ERROR: photo/video export error: contentSize is 0, attachment=%@", attachment);
                            [attachment performSafeDeletion];
                            //[AppDelegate.instance deleteObject:attachment];
                            //[self unregisterBackgroundTask];
                            [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                        }
                    } else {
                        NSLog(@"#ERROR: photo/video export failed, error: %@, attachment=%@", theError, attachment);
                        [attachment performSafeDeletion];
                        //[AppDelegate.instance deleteObject:attachment];
                        //[self unregisterBackgroundTask];
                        [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
                    }
                }];
            } else {
                NSLog(@"#ERROR: exportAndSendMultiAttachmentsToContactOrGroup: object with unhandled class %@", mediaItemOrPartner);
                [self exportAndSendMultiAttachmentsToContactOrGroup:contact];
            }
        });
    }
}

NSError * makeMediaError(NSString * reason) {
    NSString *errMsg = reason;
    NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"mediaError" code:4568 userInfo:info];
}

-(void)exportALAsset:(ALAsset*)asset intoAttachment:(Attachment*)attachment onCompletion:(CompletionBlock)completion {
    NSString * type = [asset valueForProperty:ALAssetPropertyType];
    if ([type isEqualToString:ALAssetTypePhoto]) {
        
        // TODO: handle images from a photo stream/cloud
        ALAssetRepresentation * rep = asset.defaultRepresentation;

        UIImage * myImage;
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0.2")) {
            myImage = [UIImage imageWithCGImage: rep.fullResolutionImage scale: rep.scale orientation: (UIImageOrientation)rep.orientation];
        } else {
            CGImageRef fullResImage = [rep fullResolutionImage];
// the following code needs some 64-bit library that is not there and will not link with armv7 builds
// TODO: check if we can fix this somehow so we can still run this on older devices, for now we lose image editing on them
#if 0
            NSString *adjustment = rep.metadata[@"AdjustmentXMP"];
            if (adjustment) {
                NSData *xmpData = [adjustment dataUsingEncoding:NSUTF8StringEncoding];
                CIImage *image = [CIImage imageWithCGImage:fullResImage];

                NSError *error = nil;
                NSArray *filterArray = [CIFilter filterArrayFromSerializedXMP: xmpData
                                                             inputImageExtent: image.extent
                                                                        error: &error];
                CIContext *context = [CIContext contextWithOptions:nil];
                if (filterArray && !error) {
                    for (CIFilter *filter in filterArray) {
                        [filter setValue:image forKey:kCIInputImageKey];
                        image = [filter outputImage];
                    }
                    fullResImage = [context createCGImage:image fromRect:[image extent]];
                }
            }
#endif
            myImage = [UIImage imageWithCGImage:fullResImage
                                                  scale: rep.scale
                                            orientation:(UIImageOrientation)rep.orientation];
        }


        // Always save a local copy. See https://github.com/hoccer/hoccer-xo-iphone/issues/211
        myImage = [Attachment qualityAdjustedImage:myImage];
        
        NSURL * myURL = [self acquireAndReserveFileUrlFor:@"albumImage.jpg" isTemporary:YES];
        
        float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        
        if (![UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myURL atomically:NO]) {
            NSString * reason = [NSString stringWithFormat:@"ChatViewController: exportALAsset: could not write jpeg representation of image %@ to url %@", myImage, myURL ];
            completion(makeMediaError(reason));
            return;
        };
        
        NSURL * permanentURL = [AppDelegate moveDocumentToPermanentLocation:myURL];
        attachment.ownedURL = [permanentURL absoluteString];
        
        [attachment makeImageAttachment: attachment.ownedURL
                             anOtherURL:nil
                                  image: myImage
                         withCompletion:^(NSError *theError) {
                              completion(theError);
                         }];
        
    } else if ([type isEqualToString:ALAssetTypeVideo]) {
        
        NSURL * outputURL = [self acquireAndReserveFileUrlFor:@"video.mp4" isTemporary:YES];
        
        AVAsset *sourceAsset = [AVAsset assetWithURL:
                                [NSURL URLWithString:
                                 [NSString stringWithFormat:@"%@",
                                  [[asset defaultRepresentation] url]]]];
        
        
        //NSURL * sourceURL = [asset valueForProperty:ALAssetPropertyAssetURL];
        //AVURLAsset * sourceAsset2 = [AVURLAsset assetWithURL:sourceURL];
        
        //TODO: make sure only compatible presets are used for export
        //NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:sourceAsset];
        AVAssetExportSession * exportSession = [AVAssetExportSession exportSessionWithAsset:sourceAsset presetName:[self videoQualityPreset]];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            NSError * myError = nil;
            switch (exportSession.status) {
                case AVAssetExportSessionStatusCompleted: {
                    NSLog (@"AVAssetExportSessionStatusCompleted");
                    
                    NSURL * permanentURL = [AppDelegate moveDocumentToPermanentLocation:outputURL];
                    
                    attachment.ownedURL = [permanentURL absoluteString];
                    
                    [attachment makeVideoAttachment:attachment.ownedURL anOtherURL:nil withCompletion:^(NSError *theError) {
                        completion(theError);
                     }];
                    return;
                }
                case AVAssetExportSessionStatusCancelled:
                    NSLog (@"AVAssetExportSessionStatusCancelled");
                case AVAssetExportSessionStatusFailed: {
                    NSLog (@"AVAssetExportSessionStatusFailed error=%@", exportSession.error);
                    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:&myError];
                    if (myError != nil) {
                        NSLog(@"Deleting media file failed: %@", myError);
                    }
                    completion(exportSession.error);
                    break;
                }
                case AVAssetExportSessionStatusUnknown: {
                    NSLog (@"AVAssetExportSessionStatusUnknown"); break;}
                case AVAssetExportSessionStatusExporting: {
                    NSLog (@"AVAssetExportSessionStatusExporting"); break;}
                case AVAssetExportSessionStatusWaiting: {
                    NSLog (@"AVAssetExportSessionStatusWaiting"); break;}
                default: { NSLog (@"ERROR: AVAssetExportSessionStatusWaiting: didn't get export status"); break;}
            }
        }];
    } else {
        NSString * reason = [NSString stringWithFormat:@"ChatViewController: exportALAsset: unknown media type %@ for asset %@", type, [asset valueForProperty:ALAssetPropertyAssetURL]];
        completion(makeMediaError(reason));
    }
}


-(void)createAndSendMultiAttachments {
    
    if (self.multiAttachmentExportItems == nil) {
        // no export in progress, start one with items to export
        self.multiAttachmentExportItems = [NSArray arrayWithArray:self.currentMultiAttachment];
        [AppDelegate.instance pauseDocumentMonitoring];
        [self registerBackgroundTask];
        [self exportAndSendMultiAttachmentsToContactOrGroup:self.partner];
    } else {
        // export in progress, append new partner and items to export
        NSMutableArray * extendedQueue = [NSMutableArray arrayWithArray:self.multiAttachmentExportItems];
        [extendedQueue addObject:self.partner];
        [extendedQueue addObjectsFromArray:self.currentMultiAttachment];
        self.multiAttachmentExportItems = extendedQueue;
    }
}


- (void)reallySendMessage {
    if ([self.messageField isFirstResponder]) {
        [self.autoCorrectTriggerHelper becomeFirstResponder]; // trigger autocompletion on last word ...
        [self.messageField becomeFirstResponder];     // ... without hiding the keyboard
    }
    if (self.currentMultiAttachment == nil) {
        // handle 0 or 1 attachments
        [self.chatBackend sendMessage:self.messageField.text toContactOrGroup:self.partner toGroupMemberOnly:nil withAttachment:self.currentAttachment withCompletion:nil];
        self.currentAttachment = nil;
    } else {
        // handle multiattachment
        if (self.messageField.text.length > 0) {
            // send first message with text only
            [self.chatBackend sendMessage:self.messageField.text toContactOrGroup:self.partner toGroupMemberOnly:nil withAttachment:nil withCompletion:nil];
        }
        [self createAndSendMultiAttachments];
    }
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
    } else if (_currentMultiAttachment != nil) {
        [self showAttachmentOptions];
    } else {
        self.pickingAttachment = YES;
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

/*
-(void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    NSLog(@"ChatViewController:viewWillTransitionToSize");
}

-(void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    NSLog(@"ChatViewController:willTransitionToTraitCollection");
}
*/

-(UIInterfaceOrientationMask)supportedInterfaceOrientations{
    if (DEBUG_ROTATION) NSLog(@"ChatViewController:supportedInterfaceOrientations %@",self.presentedViewController);

    // Please note that this call needs to be forwarded by the tabbar controller delegate and the navigation controller
    // in order to get called at all
    if (self.presentedViewController != nil && [self.presentedViewController isKindOfClass:[UIImagePickerController class]]) {
        // Make sure the Image Picker (which who knows why works properly only in portrait mode) will not rotate
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
    if (DEBUG_ROTATION) NSLog(@"ChatViewController:preferredInterfaceOrientationForPresentation");
    return UIInterfaceOrientationPortrait;
}

// This function will not get called on iOS >= 7
- (BOOL) shouldAutorotate {
    if (DEBUG_ROTATION) NSLog(@"ChatViewController:shouldAutorotate");
    return YES;
}


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

- (void) didPickGeoAttachment: (id) attachmentInfo into:(Attachment*)attachment {
    MKPointAnnotation * placemark = attachmentInfo[@"com.hoccer.xo.geolocation"];
    NSLog(@"got geolocation %f %f", placemark.coordinate.latitude, placemark.coordinate.longitude);
    
    UIImage * preview = attachmentInfo[@"com.hoccer.xo.previewImage"];
    //float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
    //NSData * previewData = UIImageJPEGRepresentation( preview, photoQualityCompressionSetting/10.0);
    NSData * previewData = UIImagePNGRepresentation( preview );
    
    NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike: @"location.hcrgeo" isTemporary:YES];
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
    
    myLocalURL = [AppDelegate moveDocumentToPermanentLocation:myLocalURL];
    attachment.ownedURL = [myLocalURL absoluteString];
    [attachment makeGeoLocationAttachment: attachment.ownedURL anOtherURL: nil withCompletion:^(NSError *theError) {
        [self finishPickedAttachmentProcessingWithImage: attachment.previewImage withError: theError];
    }];
}

- (void) didPickVCardAttachment: (id) attachmentInfo into:(Attachment*)attachment {
    NSData * vcardData = attachmentInfo[@"com.hoccer.xo.vcard.data"];
    // NSString * vcardString = [NSString stringWithData:vcardData usingEncoding:NSUTF8StringEncoding];
    NSString * personName = attachmentInfo[@"com.hoccer.xo.vcard.name"];
    
    // find a suitable unique file name and path
    NSString * newFileName = [NSString stringWithFormat:@"%@.vcf",personName];
    NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
    
    [vcardData writeToURL:myLocalURL atomically:NO];
    CompletionBlock completion  = ^(NSError *myerror) {
        UIImage * preview = attachment.previewImage != nil ? attachment.previewImage : [UIImage imageNamed: @"attachment_icon_contact"];
        [self finishPickedAttachmentProcessingWithImage: preview withError:myerror];
    };
    
    myLocalURL = [AppDelegate moveDocumentToPermanentLocation:myLocalURL];
    attachment.ownedURL = [myLocalURL absoluteString];
    attachment.humanReadableFileName = [myLocalURL lastPathComponent];
    [attachment makeVcardAttachment:[myLocalURL absoluteString] anOtherURL:nil withCompletion:completion];
}

- (void) didPickPasteboardAttachment: (id) attachmentInfo into:(Attachment*)attachment {
    NSString * myMediaType = attachmentInfo[@"com.hoccer.xo.mediaType"];
    attachment.mimeType = attachmentInfo[@"com.hoccer.xo.mimeType"];
    attachment.humanReadableFileName = attachmentInfo[@"com.hoccer.xo.fileName"];
    
    CompletionBlock completion  = ^(NSError *myerror) {
        [self finishPickedAttachmentProcessingWithImage: attachment.previewImage withError:myerror];
    };
    
    if ([myMediaType isEqualToString:@"image"]) {
        [attachment makeImageAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] image:nil withCompletion:completion];
    } else if ([myMediaType isEqualToString:@"video"]) {
        [attachment makeVideoAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
    } else if ([myMediaType isEqualToString:@"audio"]) {
        [attachment makeAudioAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
    } else if ([myMediaType isEqualToString:@"vcard"]) {
        [attachment makeVcardAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
    } else if ([myMediaType isEqualToString:@"geolocation"]) {
        [attachment makeGeoLocationAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
    } else if ([myMediaType isEqualToString:@"data"]) {
        [attachment makeDataAttachment: attachmentInfo[@"com.hoccer.xo.url1"] anOtherURL:attachmentInfo[@"com.hoccer.xo.url2"] withCompletion:completion];
    } else {
        NSLog(@"ERROR: didPickPasteboardAttachment: unknown media type: %@", myMediaType);
    }
}

- (BOOL) didPickPasteboardImageAttachment: (id) attachmentInfo into:(Attachment*)attachment {
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
            NSURL * myLocalURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
            
            // write the image
            myImage = [Attachment qualityAdjustedImage:myImage];
            float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
            [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myLocalURL atomically:NO];
            
            myLocalURL = [AppDelegate moveDocumentToPermanentLocation:myLocalURL];
            attachment.ownedURL = [myLocalURL absoluteString];
            attachment.humanReadableFileName = [myLocalURL lastPathComponent];
            [attachment makeImageAttachment: [myLocalURL absoluteString] anOtherURL:nil
                                                  image: myImage
                                         withCompletion:^(NSError *theError) {
                                             [self finishPickedAttachmentProcessingWithImage: myImage withError:theError];
                                         }];
            return YES;
        } else {
            NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: com.hoccer.xo.pastedImage is not an image, object is of class = %@", [myImageObject class]];
            NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 555 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            
            [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
            return YES;
        }
    }
    return NO;
}

- (void) didPickMPMediaAttachment: (id) attachmentInfo into:(Attachment*)attachment inSession:(AVAssetExportSession* __strong *)exportSession withCompletion:(ImageCompletionBlock)completion {
    // probably an audio item media library
    MPMediaItem * song = (MPMediaItem*)attachmentInfo;
    
    // make a nice and unique filename
    NSString * newFileName = [NSString stringWithFormat:@"%@ - %@.%@",[song valueForProperty:MPMediaItemPropertyArtist],[song valueForProperty:MPMediaItemPropertyTitle],@"m4a" ];
    
    NSURL * myExportURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
    
    NSURL *assetURL = [song valueForProperty:MPMediaItemPropertyAssetURL];
    // NSLog(@"audio assetURL = %@", assetURL);
    
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    if ([songAsset hasProtectedContent] == YES) {
        // TODO: user dialog here
        NSLog(@"Media is protected by DRM");
        NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: Media is protected by DRM"];
        NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 557 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        completion(nil,myError);
        return;
    }
    if (*exportSession != nil) {
        NSString * myDescription = [NSString stringWithFormat:@"An audio or video export is still in progress"];
        NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
        completion(nil,myError);
        return;
    }
    
    *exportSession = [[AVAssetExportSession alloc]
                             initWithAsset: songAsset
                             presetName: AVAssetExportPresetAppleM4A];
    
    
    (*exportSession).outputURL = myExportURL;
    (*exportSession).outputFileType = AVFileTypeAppleM4A;
    (*exportSession).shouldOptimizeForNetworkUse = YES;
    
    AVMutableMetadataItem * titleItem = [AVMutableMetadataItem metadataItem];
    titleItem.keySpace = AVMetadataKeySpaceCommon;
    titleItem.key = AVMetadataCommonKeyTitle;
    titleItem.value = [song valueForProperty:MPMediaItemPropertyTitle];
    
    AVMutableMetadataItem * artistItem = [AVMutableMetadataItem metadataItem];
    artistItem.keySpace = AVMetadataKeySpaceCommon;
    artistItem.key = AVMetadataCommonKeyArtist;
    artistItem.value = [song valueForProperty:MPMediaItemPropertyArtist];
    
    AVMutableMetadataItem * albumItem = [AVMutableMetadataItem metadataItem];
    albumItem.keySpace = AVMetadataKeySpaceCommon;
    albumItem.key = AVMetadataCommonKeyAlbumName;
    albumItem.value = [song valueForProperty:MPMediaItemPropertyAlbumTitle];
    
    MPMediaItemArtwork * artwork = [song valueForProperty:MPMediaItemPropertyArtwork];
    UIImage * artworkImage = [artwork imageWithSize:artwork.bounds.size];
    
    AVMutableMetadataItem * artworkItem = [AVMutableMetadataItem metadataItem];
    artworkItem.keySpace = AVMetadataKeySpaceCommon;
    artworkItem.key = AVMetadataCommonKeyArtwork;
    artworkItem.value = UIImageJPEGRepresentation(artworkImage, 0.6);
    
    (*exportSession).metadata = @[titleItem, artistItem, albumItem, artworkItem];
    
    [*exportSession exportAsynchronouslyWithCompletionHandler:^{
        AVAssetExportSessionStatus exportStatus = (*exportSession).status;
        switch (exportStatus) {
            case AVAssetExportSessionStatusFailed: {
                NSLog (@"AVAssetExportSessionStatusFailed");
                // log error to text view
                NSString * myDescription = [NSString stringWithFormat:@"Audio export failed (AVAssetExportSessionStatusFailed)"];
                NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                *exportSession = nil;
                completion(nil,myError);
                break;
            }
            case AVAssetExportSessionStatusCompleted: {
                if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted");
                
                NSURL * permanetExportURL = [AppDelegate moveDocumentToPermanentLocation:myExportURL];
                attachment.ownedURL = [permanetExportURL absoluteString];
                attachment.humanReadableFileName = [permanetExportURL lastPathComponent];
                
                [attachment makeAudioAttachment: [assetURL absoluteString] anOtherURL:attachment.ownedURL withCompletion:^(NSError *theError) {
                    *exportSession = nil;
                    if (attachment.previewImage == nil) {
                        if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: makeAudioAttachment - creating preview image from db artwork");
                        // In case we fail getting the artwork from file try get artwork from Media Item
                        // However, this only displays the artwork on the upload side. The artwork is *not*
                        // included in the exported file.
                        // It should be possible to add the image using (*exportSession).metadata. But
                        // merging with existing metadata is non trivial and we should tackle it later.
                        MPMediaItemArtwork * artwork = [song valueForProperty:MPMediaItemPropertyArtwork];
                        if (artwork != nil) {
                            if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: got artwork, creating preview image");
                            attachment.previewImage = [artwork imageWithSize:CGSizeMake(400,400)];
                        } else {
                            if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: no artwork");
                        }
                    } else {
                        if (DEBUG_ATTACHMENT_BUTTONS) NSLog (@"AVAssetExportSessionStatusCompleted: artwork is in media file");
                    }
                    completion(attachment.previewImage,theError);
                    //[self finishPickedAttachmentProcessingWithImage: attachment.previewImage withError:theError];
                }];
                break;
            }
            case AVAssetExportSessionStatusUnknown: {
                NSLog (@"AVAssetExportSessionStatusUnknown"); break;}
            case AVAssetExportSessionStatusExporting: {
                NSLog (@"AVAssetExportSessionStatusExporting"); break;}
            case AVAssetExportSessionStatusCancelled: {
                NSError * error = (*exportSession).error;
                *exportSession = nil;
                //[self finishPickedAttachmentProcessingWithImage: nil withError:(*exportSession).error];
                completion(nil,error);
                // NSLog (@"AVAssetExportSessionStatusCancelled");
                break;
            }
            case AVAssetExportSessionStatusWaiting: {
                NSLog (@"AVAssetExportSessionStatusWaiting"); break;}
            default: { NSLog (@"ERROR: AVAssetExportSessionStatusWaiting: didn't get export status"); break;}
        }
    }];
}

- (void) didPickCameraOrAlbumImageAttachment: (id) attachmentInfo into:(Attachment*)attachment {
    __block NSURL * myURL = attachmentInfo[UIImagePickerControllerReferenceURL];
    if (attachmentInfo[UIImagePickerControllerMediaMetadata] != nil) {
        // Image was just taken and is not yet in album
        
        UIImage * myOriginalImage = attachmentInfo[UIImagePickerControllerOriginalImage];

        NSURL * myFileURL = nil;
        
        // Always save a local copy. See https://github.com/hoccer/hoccer-xo-iphone/issues/211
        UIImage * myImage = [Attachment qualityAdjustedImage:myOriginalImage];
        NSString * newFileName = @"snapshot.jpg";
        myFileURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
        
        float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myFileURL atomically:NO];
        
        myURL = [AppDelegate moveDocumentToPermanentLocation:myFileURL];
        attachment.ownedURL = [myURL absoluteString];
        attachment.humanReadableFileName = [myURL lastPathComponent];
        // create attachment with lower quality image dependend on settings
        [attachment makeImageAttachment: attachment.ownedURL
                             anOtherURL:nil
                                  image: myImage
                         withCompletion:^(NSError *theError) {
                             [self finishPickedAttachmentProcessingWithImage: attachment.previewImage withError:theError];
                         }];
       
        // write full size full quality image to library if authorized
        ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
        
        if (status == ALAuthorizationStatusDenied || status == ALAuthorizationStatusRestricted) {
            //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Attention" message:@"Please give this app permission to access your photo library in your settings app!" delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil, nil];
            //[alert show];
            NSLog(@"Not saving photo to album because album access is denied");
        } else {
            if(myImage) {
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        
                     } else {
                        NSLog(@"Error saving image in Library, error = %@", error);
                        [self finishPickedAttachmentProcessingWithImage: nil withError:error];
                    }
                };
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeImageToSavedPhotosAlbum:[myOriginalImage CGImage]
                                          orientation:(ALAssetOrientation)[myOriginalImage imageOrientation]
                                      completionBlock:completeBlock];
            }
        }
    } else {
        // image from album
        UIImage * myImage = attachmentInfo[UIImagePickerControllerOriginalImage];
        // Always save a local copy. See https://github.com/hoccer/hoccer-xo-iphone/issues/211
        //if ([Attachment tooLargeImage:myImage]) {
        myImage = [Attachment qualityAdjustedImage:myImage];
        NSString * newFileName = @"albumImage.jpg";
        myURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
        
        float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
        [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myURL atomically:NO];
        //} else {
        //  TODO: save a local copy of the image without JPEG reencoding
        //}
        myURL = [AppDelegate moveDocumentToPermanentLocation:myURL];
        attachment.ownedURL = [myURL absoluteString];
        attachment.humanReadableFileName = [myURL lastPathComponent];
        [attachment makeImageAttachment: attachment.ownedURL
                                         anOtherURL:nil
                                              image: myImage
                                     withCompletion:^(NSError *theError) {
                                         [self finishPickedAttachmentProcessingWithImage: myImage
                                                                               withError:theError];
                                     }];
    }
}

- (void) didPickCameraOrAlbumMovieAttachment: (id) attachmentInfo into:(Attachment*)attachment {
    NSURL * referenceURL = attachmentInfo[UIImagePickerControllerReferenceURL];
    NSURL * mediaURL = attachmentInfo[UIImagePickerControllerMediaURL];
    [self didPickCameraOrAlbumMovieAttachmentWithUrl:mediaURL withReferenceUrl:referenceURL into:attachment];
}

- (void) didPickCameraOrAlbumMovieAttachmentWithUrl:(NSURL *)mediaURL withReferenceUrl:(NSURL *) referenceURL into:(Attachment*)attachment {
    
    NSString * newFileName = @"video.mp4";
    NSURL * outputURL = [AppDelegate uniqueNewFileURLForFileLike:newFileName isTemporary:YES];
    
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
                
                // write full size full quality image to library if authorized
                ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
                
                if (status == ALAuthorizationStatusDenied || status == ALAuthorizationStatusRestricted) {
                    NSLog(@"Not saving video to album because album access is denied");
                } else {
                
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
            }
            
            NSURL * permanentURL = [AppDelegate moveDocumentToPermanentLocation:outputURL];
            attachment.ownedURL = [permanentURL absoluteString];
            attachment.humanReadableFileName = [permanentURL lastPathComponent];
            
            [attachment makeVideoAttachment:attachment.ownedURL anOtherURL:nil withCompletion:^(NSError *theError) {
                [self finishPickedAttachmentProcessingWithImage:attachment.previewImage withError:theError];
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
}

// If scale is 0, iscreen scale is used to create the bounds
+ (UIImage *)imageFromView:(UIView*)view withScale:(CGFloat)scale {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, scale);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return copied;
}

+ (UIImage*)createMultiAttachmentPreview:(NSArray*)multiAttachment {
    UILabel * label = [UILabel new];
    label.frame = CGRectMake(0,0,30,30);
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [HXOUI theme].tintColor;
    label.textColor = [HXOUI theme].navigationBarBackgroundColor;
    label.text = @(multiAttachment.count).stringValue;
    UIImage * preview = [ChatViewController imageFromView:label withScale:4.0];
    return preview;
}

- (void) didPickAttachment: (id) attachmentInfo {
    if (attachmentInfo == nil) {;
        return;
    }
    [self startPickedAttachmentProcessingForObject:attachmentInfo];
    //NSLog(@"didPickAttachment: attachmentInfo = %@",attachmentInfo);
    
    if ([attachmentInfo isKindOfClass:[NSArray class]]) {
        NSArray * infos = attachmentInfo;
        if (infos.count == 1) {
            // only 1 item selected
            id item = infos[0];
            if ([item isKindOfClass: [MPMediaItem class]]) {
                attachmentInfo = item;
            } else if ([item isKindOfClass:[ALAsset class]]) {
                attachmentInfo = item;
            }
        } else if (infos.count > 1) {
            
            // multi attachment
            self.currentMultiAttachment = attachmentInfo;
            UIImage * preview = [ChatViewController createMultiAttachmentPreview:self.currentMultiAttachment];
            [self finishPickedAttachmentProcessingWithImage:preview withError:nil];
            return;
        } else {
            // zero size array returned
            self.currentMultiAttachment = nil;
            [self finishPickedAttachmentProcessingWithImage:nil withError:nil];
            return;
        }
    } else {
        self.currentMultiAttachment = nil;
    }

    self.currentAttachment = (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                        inManagedObjectContext: AppDelegate.instance.mainObjectContext];

    
    if ([attachmentInfo isKindOfClass:[ALAsset class]]) {
        ALAsset * asset = attachmentInfo;
        [self exportALAsset:asset intoAttachment:self.currentAttachment onCompletion:^(NSError *theError) {
            if (theError == nil) {
                [self finishPickedAttachmentProcessingWithImage:self.currentAttachment.previewImage withError:nil];
            } else {
                [self finishPickedAttachmentProcessingWithImage:nil withError:theError];
            }
        }];
        return;
    }
    
    // handle geolocation
    if ([attachmentInfo isKindOfClass: [NSDictionary class]] &&
        [attachmentInfo[@"com.hoccer.xo.mediaType"] isEqualToString: @"geolocation"] &&
        [attachmentInfo[@"com.hoccer.xo.previewImage"] isKindOfClass: [UIImage class]])
    {
        [self didPickGeoAttachment:attachmentInfo into:self.currentAttachment];
        return;
    }

    // handle vcard picked from adressbook
    if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        if (attachmentInfo[@"com.hoccer.xo.vcard.data"] != nil) {
            [self didPickVCardAttachment:attachmentInfo into:self.currentAttachment];
            return;
        }
    }
    
    // handle stuff from pasteboard
    if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        if (attachmentInfo[@"com.hoccer.xo.mediaType"] != nil) {
            // attachment from pasteBoard
            [self didPickPasteboardAttachment:attachmentInfo into:self.currentAttachment];
            return;
        }
        if ([self didPickPasteboardImageAttachment:attachmentInfo into:self.currentAttachment]) {
            return;
        }
    }
    
    if ([attachmentInfo isKindOfClass: [MPMediaItem class]]) {
        [self didPickMPMediaAttachment:attachmentInfo into:self.currentAttachment inSession:&_currentExportSession withCompletion:^(UIImage *image, NSError *error) {
            [self finishPickedAttachmentProcessingWithImage: image withError:error];
        }];
        return;
        
    } else if ([attachmentInfo isKindOfClass: [NSDictionary class]]) {
        // image or movie from camera or album
        
        NSString * mediaType = attachmentInfo[UIImagePickerControllerMediaType];
                
        if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeImage)) {
            [self didPickCameraOrAlbumImageAttachment:attachmentInfo into:self.currentAttachment];
            return;
        } else if (UTTypeConformsTo((__bridge CFStringRef)(mediaType), kUTTypeVideo) || [mediaType isEqualToString:@"public.movie"]) {
            [self didPickCameraOrAlbumMovieAttachment:attachmentInfo into:self.currentAttachment];
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
    NSLog(@"startPickedAttachmentProcessingForObject:%@",_currentPickInfo);
    if (_currentAttachment != nil) {
        [self trashCurrentAttachment];
    }
    _currentPickInfo = info;
    //[self.attachmentButton startSpinning]; // will be started in viewWillAppear to fix bug in iOS9
    self.startAttachmentSpinnerWhenViewAppears = YES;
    self.sendButton.enabled = NO; // wait for attachment ready
}

- (void) finishPickedAttachmentProcessingWithImage:(UIImage*) theImage withError:(NSError*) theError {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage:%@ previewIcon:%@ withError:%@",theImage, self.currentAttachment.previewIcon, theError);
        _currentPickInfo = nil;

        [self.attachmentButton stopSpinning];

        if (theError == nil && theImage != nil) {
            
            if (DEBUG_ATTACHMENT_BUTTONS)NSLog(@"finishPickedAttachmentProcessingWithImage attachment = %@", self.currentAttachment);
            
            if (theImage.size.height == 0) {
                if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with currentAttachment.previewIcon");
                [self decorateAttachmentButton:self.currentAttachment.previewIcon];
            } else {
                if (DEBUG_ATTACHMENT_BUTTONS)NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with theImage");
                [self decorateAttachmentButton:theImage];
            }
            self.sendButton.enabled = YES;
            self.hasPickedAttachment = YES;
        } else {
            if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: trashCurrentAttachment");
            [self trashCurrentAttachment];
        }
        self.pickingAttachment = NO;
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
        /*
        [AppDelegate.instance saveContext];
        NSManagedObjectID * currentAttachmentId = self.currentAttachment.objectID;
        [AppDelegate.instance performWithLockingId:@"adoptOrphanedFiles" inNewBackgroundContext:^(NSManagedObjectContext *context) {
            Attachment * currentAttachment = (Attachment*)[context objectWithID:currentAttachmentId];
            [AppDelegate.instance deleteObject:currentAttachment inContext:context];
        }];
         */
        [self.currentAttachment performSafeDeletion];
        self.currentAttachment = nil;
    }
    if (self.currentMultiAttachment != nil) {
        self.currentMultiAttachment = nil;
    }
    [self decorateAttachmentButton:nil];
    self.pickingAttachment = NO;
    self.hasPickedAttachment = NO;
    // TODO:
    //_attachmentButton.hidden = NO;
}

- (void) showAttachmentOptions {
    UIActionSheet * sheet = nil;
    if (self.currentMultiAttachment) {
        sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"attachment_option_sheet_title_pl", nil)
                                            delegate: self
                                   cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                              destructiveButtonTitle: nil
                                   otherButtonTitles: NSLocalizedString(@"attachment_option_remove_btn_title_pl", nil),
                 NSLocalizedString(@"attachment_option_choose_new_btn_title_pl", nil),
                 NSLocalizedString(@"attachment_option_view_btn_title_pl", nil),
                 nil];
    } else {
        sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"attachment_option_sheet_title", nil)
                                            delegate: self
                                   cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                              destructiveButtonTitle: nil
                                   otherButtonTitles: NSLocalizedString(@"attachment_option_remove_btn_title", nil),
                 NSLocalizedString(@"attachment_option_choose_new_btn_title", nil),
                 NSLocalizedString(@"attachment_option_view_btn_title", nil),
                 nil];
    }
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet showInView: self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // NSLog(@"Clicked button at index %d", buttonIndex);
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^ {
        switch (buttonIndex) {
            case 0:
                // attachment_option_remove_btn_title pressed
                [self trashCurrentAttachment];
                break;
            case 1:
                self.pickingAttachment = YES;
                [self trashCurrentAttachment];
                [self.attachmentPicker showInView: self.view];
                // NSLog(@"Pick new attachment");
                break;
            case 2:
                if (self.currentMultiAttachment != nil) {
                    [self.attachmentPicker pickMultipleImages:self.currentMultiAttachment];
                } else {
                    [self presentViewForAttachment: self.currentAttachment];
                }
                // NSLog(@"Viewing current attachment");
                break;
            default:
                break;
        }
    });
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

    if (message.attachment.available && !message.attachment.fileUnavailable) {
        [self presentViewForAttachment: message.attachment];
    }
}

- (CGFloat)calcAndCacheCellHeight:(MessageCell*)cell forMessage:(HXOMessage*)message {
    CGFloat height = [cell sizeThatFits: CGSizeMake(self.tableView.bounds.size.width, FLT_MAX)].height;

    if (CGRectGetWidth(_tableView.bounds) == [UIScreen mainScreen].applicationFrame.size.width) {
        message.cachedCellHeight = height;
    } else {
        if (DEBUG_CELL_HEIGHT_CACHING) {
        NSLog(@"calcAndCacheCellHeight: Tableview width = %f, screen width %f", CGRectGetWidth(_tableView.bounds), [UIScreen mainScreen].applicationFrame.size.width);
        NSLog(@"calcAndCacheCellHeight: not caching height for prefinal tableview");
        }
    }
    if (DEBUG_CELL_HEIGHT_CACHING) NSLog(@"calcAndCacheCellHeight: returning new calculated value %f, cached value = %f", height, message.cachedCellHeight);
    return height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];


    if (CGRectGetWidth(_tableView.bounds) != [UIScreen mainScreen].applicationFrame.size.width) {
        if (DEBUG_CELL_HEIGHT_CACHING) NSLog(@"Tableview width = %f, screen width %f", CGRectGetWidth(tableView.bounds), [UIScreen mainScreen].applicationFrame.size.width);
        CGFloat myHeight = CGRectGetHeight(_tableView.bounds)/4.0;
        if (DEBUG_CELL_HEIGHT_CACHING) NSLog(@"heightForRowAtIndexPath: returning faked cached value %f", myHeight);
        return myHeight;
    }
    
    CGFloat myHeight = message.cachedCellHeight;
    if (myHeight != 0) {
        if (DEBUG_CELL_HEIGHT_CACHING) NSLog(@"heightForRowAtIndexPath: returning cached value %f", myHeight);
        return myHeight;
    }

    MessageCell * cell = [_cellPrototypes objectForKey: [self cellIdentifierForMessage: message]];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        // On iOS 8 UITableView automaticallay calls reloadData on UIContentSizeCategoryDidChangeNotification
        // *before* our handler has a chance to reconfigure anything. That means the cache already grabs the new
        // font size value but performs computations on cells that still use the old. As a workaround we enforce
        // an update before updating the cache
        if (DEBUG_CELL_HEIGHT_CACHING) NSLog(@"heightForRowAtIndexPath: forcing >iOS 8.0 layout update.");
        for (id section in [cell sections]) {
            if ([section respondsToSelector: @selector(preferredContentSizeChanged:)]) {
                [section preferredContentSizeChanged: nil];
            }
        }
    }
    
    [self configureCell: cell forMessage: message withAttachmentPreview:NO];
    
    return [self calcAndCacheCellHeight:cell forMessage:message];
}

- (NSString*) cellIdentifierForMessage: (HXOMessage*) message {
    BOOL hasAttachment = message.attachment != nil;
    BOOL hasText = message.body != nil && ! [message.body isEqualToString: @""];
    if (hasAttachment) {
        if ([self hasImageAttachment: message]) {
            return hasText ? [ImageAttachmentWithTextMessageCell reuseIdentifier] : [ImageAttachmentMessageCell reuseIdentifier];
        } else if ([self hasAudioAttachment: message]) {
            return hasText ? [AudioAttachmentWithTextMessageCell reuseIdentifier] : [AudioAttachmentMessageCell reuseIdentifier];
        } else {
            return hasText ? [GenericAttachmentWithTextMessageCell reuseIdentifier] : [GenericAttachmentMessageCell reuseIdentifier];
        }
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

- (BOOL) hasAudioAttachment: (HXOMessage*) message {
    return [message.attachment.mediaType isEqualToString: @"audio"];
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
            [(AppDelegate *)(self.chatBackend.delegate) showFatalErrorAlertWithMessage:nil withTitle:nil];
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
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addContactKVO: self.observedContacts.count = %d", (int)self.observedContacts.count);
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
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeContactKVO: self.observedContacts.count = %d", (int)self.observedContacts.count);
}

- (void) removeAllContactKVOs {
    if (DEBUG_OBSERVERS) NSLog(@"ContactSheetController: removeAllContactKVOs");
    NSSet * registered = [NSSet setWithSet:self.observedContacts]; // avoid enumeration mutation exception
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeAllContactKVOs: registered.count = %d", (int)registered.count);
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
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:addMembersKVO: self.observedMembersGroups.count = %d", (int)self.observedMembersGroups.count);
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
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeMembersKVO: self.observedMembersGroups.count = %d", (int)self.observedMembersGroups.count);
}

- (void) removeAllMembersKVOs {
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController: removeAllMembersKVOs");
    NSSet * registered = [NSSet setWithSet:self.observedMembersGroups]; // avoid enumeration mutation exception
    if (DEBUG_OBSERVERS) NSLog(@"ChatViewController:removeAllMembersKVOs: registered.count = %d", (int)registered.count);
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
            if (self.partner.isNearby || self.partner.isWorldwide) {
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
        // XXX magic numbers
        frame.size.height = MIN(150, MAX( 50 - 2 * kHXOGridSpacing, self.messageField.contentSize.height));
        self.messageField.frame = frame;
        self.messageField.accessibilityFrame = self.messageField.frame;

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
        MessageCell * cell = (MessageCell*)[self.tableView cellForRowAtIndexPath:indexPath];
        [self configureCell: cell forMessage: message withAttachmentPreview:YES];
        [self calcAndCacheCellHeight:cell forMessage:message];
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
        case NSFetchedResultsChangeMove:
        case NSFetchedResultsChangeUpdate:
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
                [self calcAndCacheCellHeight:cell forMessage:message];
            }
            break;
        }

        case NSFetchedResultsChangeMove:
            //NSLog(@"NSFetchedResultsChangeMove");
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationNone];
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
    return self.isViewLoaded && self.view.window && !AppDelegate.instance.runningInBackground;
}

- (void)configureCell:(MessageCell*)cell forMessage:(HXOMessage *) message withAttachmentPreview:(BOOL)loadPreview {
    if (cell == nil) {
        NSLog(@"#WARNING: ChatViewController:configureCell called with cell = nil");
        NSLog(@"%@", [NSThread callStackSymbols]);
        return;
    }
    if (message.isDeleted) {
        NSLog(@"#WARNING: ChatViewController:configureCell called with deleted message");
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
    NSString * accessibilityLabel;
    if (message.isOutgoing) {
        accessibilityLabel = [NSString stringWithFormat:@"%@ %@ %@",NSLocalizedString(@"accessibiltiy_outgoing_message", nil), NSLocalizedString(@"accessibiltiy_to", nil),message.contact.nickNameOrAlias];
    } else {
        accessibilityLabel = [NSString stringWithFormat:@"%@ %@ %@",NSLocalizedString(@"accessibiltiy_incoming_message", nil), NSLocalizedString(@"accessibiltiy_from", nil),message.contact.nickNameOrAlias];
    }
    cell.accessibilityLabel = accessibilityLabel;
    cell.accessibilityValue = message.body;

    for (MessageSection * section in cell.sections) {
        if ([section isKindOfClass: [TextSection class]]) {
            [self configureTextSection: (TextSection*)section forMessage: message];
        } else if ([section isKindOfClass: [ImageAttachmentSection class]]) {
            [self configureImageAttachmentSection: (ImageAttachmentSection*)section forMessage: message withAttachmentPreview:loadPreview];
        } else if ([section isKindOfClass: [AudioAttachmentSection class]]) {
            [self configureAudioAttachmentSection: (AudioAttachmentSection*)section forMessage: message];
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
    message.attachment.uiDelegate = self;
    [section.upDownLoadControl addTarget: self action: @selector(didToggleTransfer:) forControlEvents: UIControlEventTouchUpInside];
    [self configureUpDownLoadControl: section.upDownLoadControl attachment: message.attachment];

    section.subtitle.text = [self attachmentSubtitle: message.attachment];

}

- (void) configureUpDownLoadControl: (UpDownLoadControl*) upDownLoadControl attachment: (Attachment*) attachment{
    upDownLoadControl.hidden = attachment.available && (attachment.state == kAttachmentTransfered || attachment.fileUnavailable);
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
/*
    NSString * title = message.attachment.humanReadableFileName;
    if (title == nil || [title isEqualToString: @""]) {
        title = @"<>";
    }
 */
    section.title.text = [self attachmentTitle: message];
    if (message.attachment.fileUnavailable) {
        section.title.attributedText = [self strikeThroughText:section.title.text];
    }
    
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
        if (message.attachment.fileUnavailable) {
            imageSection.showCorrupted =YES;
        } else {
            imageSection.showCorrupted = NO;
        }
        imageSection.subtitle.hidden = imageSection.image != nil;
        imageSection.showPlayButton = [attachment.mediaType isEqualToString: @"video"] && imageSection.image != nil;
    }
}

- (NSAttributedString*) strikeThroughText:(NSString*)title {
    NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
    NSRange range = NSMakeRange(0,title.length);
    [attributedTitle setAttributes:@{ NSStrikethroughStyleAttributeName: @(YES),
                                      NSStrikethroughColorAttributeName: [UIColor redColor] } range:range];
    return attributedTitle;
}

- (void) configureAudioAttachmentSection: (AudioAttachmentSection*) section forMessage: (HXOMessage*) message {
    [self configureAttachmentSection: section forMessage: message];
    section.title.text = [self attachmentTitle: message];
    
    Attachment *attachment = message.attachment;

    if (attachment.fileUnavailable) {
        section.title.attributedText = [self strikeThroughText:section.title.text];
    }
    
    if (attachment.state == kAttachmentTransfered) {
        section.playbackButtonController = [[HXOAudioPlaybackButtonController alloc] initWithButton:section.playbackButton attachment:attachment];
        section.playbackButton.hidden = NO;
    } else {
        section.playbackButtonController = nil;
        section.playbackButton.hidden = YES;
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
    NSLog(@"ERROR: colorSchemeForMessage: strange deliveries for message id '%@', delivery count=%d", message.messageId, (int)message.deliveries.count);
    return HXOBubbleColorSchemeSuccess;
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

    NSMutableArray * info = [NSMutableArray array];
    if (newCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)newCount, [self stateStringForDelivery:messagesNew.anyObject]]];
    }
    if (deliveringCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)deliveringCount, [self stateStringForDelivery:messagesDelivering.anyObject]]];
    }
    if (failedCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)failedCount, [self stateStringForDelivery:messagesFailed.anyObject]]];
    }
    
    if (message.attachment != nil) {
        //NSSet * attachmentsMissing = message.deliveriesAttachmentsMissing;
        //NSUInteger attachmentMissingCount = attachmentsMissing.count;
        
        NSSet * attachmentsPending = message.deliveriesAttachmentsPending;
        //NSUInteger attachmentPendingCount = attachmentsPending.count;
        
        NSSet * attachmentsFailed = message.deliveriesAttachmentsFailed;
        NSUInteger attachmentFailedCount = attachmentsFailed.count;
        
        NSSet * attachmentsReceived = message.deliveriesAttachmentsReceived;
        //NSUInteger attachmentReceivedCount = attachmentsReceived.count;
        
        if (attachmentFailedCount != 0) {
            [info addObject: [NSString stringWithFormat:@"%d %@", (int)attachmentFailedCount, [self stateStringForDelivery:attachmentsFailed.anyObject]]];
        }
        attachmentsPending = differenceOfSets(attachmentsPending, messagesDelivering);
        attachmentsPending = differenceOfSets(attachmentsPending, messagesNew);
        NSUInteger attachmentPendingCount = attachmentsPending.count;
        
        if (attachmentPendingCount != 0) {
            [info addObject: [NSString stringWithFormat:@"%d %@", (int)attachmentPendingCount, [self stateStringForDelivery:attachmentsPending.anyObject]]];
        }
        messagesSeen = intersectionOfSets(messagesSeen,attachmentsReceived);
        seenCount = messagesSeen.count;
        
        messagesUnseen = intersectionOfSets(messagesUnseen,attachmentsReceived);
        unseenCount = messagesUnseen.count;
        
        messagesPrivate = intersectionOfSets(messagesPrivate,attachmentsReceived);
        privateCount = messagesPrivate.count;
    }
    if (seenCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)seenCount, [self stateStringForDelivery:messagesSeen.anyObject]]];
    }
    if (unseenCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)unseenCount, [self stateStringForDelivery:messagesUnseen.anyObject]]];
    }
    if (privateCount != 0) {
        [info addObject: [NSString stringWithFormat:@"%d %@", (int)privateCount, [self stateStringForDelivery:messagesPrivate.anyObject]]];
    }
    
#ifdef DEBUG
    [info addObject: [NSString stringWithFormat:@" (%d)", (int)totalDeliveries]];
#endif
    return [info componentsJoinedByString:@", "];
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
            NSString * stateString = [NSString stringWithFormat:NSLocalizedString(@"chat_message_delivered_failed_attachment %@", nil),
                                      NSLocalizedString(attachment_type, nil)];
            return stateString;
        } else  if (myDelivery.isAttachmentPending) {
            NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", myDelivery.message.attachment.mediaType];
            NSString * stateString = [NSString stringWithFormat:NSLocalizedString(@"chat_message_delivered_missing_attachment %@", nil),
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
        NSString * author = [[self getAuthor: message] nickNameOrAlias];
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
        return [[self getAuthor: message] nickNameOrAlias];
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
        if ([attachment.humanReadableFileName hasPrefix:@"recording"]) {
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
            title = item.attachmentInfo.vcardName;
        } else if ([attachment.mediaType isEqualToString: @"geolocation"]) {
            title = NSLocalizedString(@"attachment_type_geolocation", nil);
        } else if ([attachment.mediaType isEqualToString: @"audio"]) {
            title = item.attachmentInfo.audioTitle;
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
    if (item.attachmentInfo) {
        AttachmentInfo *attachmentInfo = item.attachmentInfo;

        if ([attachment.mediaType isEqualToString: @"vcard"]) {
            NSString * info = attachmentInfo.vcardEmail;
            if (! info) {
                info = attachmentInfo.vcardOrganization;
            }
            subtitle = info;
        } else if ([attachment.mediaType isEqualToString: @"audio"]) {
            subtitle = attachmentInfo.audioArtistAlbumAndDuration;
        }
            
    }
    if (subtitle == nil) {
        NSString * attachment_type = [NSString stringWithFormat: @"attachment_type_%@", attachment.mediaType];
        NSString * name = attachment.humanReadableFileName != nil ? attachment.humanReadableFileName : NSLocalizedString(attachment_type, nil);
        subtitle = [NSString stringWithFormat: @"%@ – %@", name, sizeString];
     }
    return subtitle;
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
            [self.chatBackend forwardMessage: numberedBody toContactOrGroup:message.contact toGroupMemberOnly:nil withAttachment:message.attachment withCompletion:nil];
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
    if (attachment != nil && attachment.available && !attachment.fileUnavailable) {
        [attachment trySaveToAlbum];
    }
}

- (void) messageCell:(MessageCell *)theCell openWithMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    Attachment * attachment = message.attachment;
    if (attachment != nil && attachment.available && !attachment.fileUnavailable) {
        [self openWithInteractionController:message];
    }
}

- (void) messageCell:(MessageCell *)theCell shareMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self openWithActivityController:message fromView:self.navigationItem.titleView];
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
    [ChatViewController presentViewForAttachment:myAttachment withDelegate:self];
}

+ (void) presentViewForAttachment:(Attachment *) myAttachment withDelegate:(id<AttachmentPresenterDelegate>)delegate {
    if ([myAttachment.mediaType isEqual: @"data"]
        || [myAttachment.mediaType isEqual: @"video"]
        // guard against old DB entries triggering https://github.com/hoccer/hoccer-xo-iphone/issues/211
        || ([myAttachment.mediaType isEqual: @"image"] && myAttachment.localURL != nil)
        //|| [myAttachment.mediaType isEqual: @"audio"]
        )
    {
        [delegate previewAttachment:myAttachment];
    } else  if ([myAttachment.mediaType isEqual: @"video"]) {
        // TODO: lazily allocate _moviePlayerController once
        delegate.moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        delegate.moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeNone;
        delegate.moviePlayerViewController.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
        [delegate.thisViewController presentMoviePlayerViewControllerAnimated: delegate.moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"image"]) {
        // used with old DB entries preventing https://github.com/hoccer/hoccer-xo-iphone/issues/211
        [myAttachment loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"attachment view loadimage done");
            if (theImage != nil) {
                delegate.imageViewController.image = theImage;
                //[self presentViewController: self.imageViewController animated: YES completion: nil];
                [delegate.thisViewController.navigationController pushViewController: delegate.imageViewController animated: YES];
            } else {
                NSLog(@"image attachment view: Failed to get image: %@", error);
            }
        }];
    } else  if ([myAttachment.mediaType isEqual: @"vcard"]) {
        Vcard * myVcard = [[Vcard alloc] initWithVcardURL:myAttachment.contentURL];
        delegate.vcardViewController.unknownPersonViewDelegate = delegate;
        delegate.vcardViewController.displayedPerson = myVcard.person; // Assume person is already defined.
        delegate.vcardViewController.allowsAddingToAddressBook = YES;
        [delegate.thisViewController.navigationController pushViewController:delegate.vcardViewController animated:YES];
    } else  if ([myAttachment.mediaType isEqual: @"geolocation"]) {
        if (AppDelegate.instance.internetReachabilty.isReachable) {
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
                    delegate.imageViewController.image = theImage;
                    [delegate.thisViewController presentViewController: delegate.imageViewController animated: YES completion: nil];
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
        CGRect navRect = self.navigationController.navigationBar.frame;
        [self.interactionController presentOpenInMenuFromRect:navRect inView:self.view animated:YES];
 
    }
}

- (void) openWithActivityController:(HXOMessage *)message fromView:(UIView*)sourceView{
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
        if ( [activityViewController respondsToSelector:@selector(popoverPresentationController)] ) {
            // iOS8
            activityViewController.popoverPresentationController.sourceView = sourceView;
        }
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
	return self.navigationController;
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

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application {
    NSLog(@"willBeginSendingToApplication %@", application);
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application {
    NSLog(@"didEndSendingToApplication %@", application);
}

- (UIViewController*) thisViewController {
    return self;
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
        //NSLog(@"scrollToRememberedCell");
        [self scrollToCell:self.partner.rememberedLastVisibleChatCell];
    } else {
        //NSLog(@"scrollToBottomAnimated");
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
        attachment.uiDelegate = nil;
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

- (void) attachmentDidChangeAspectRatio:(Attachment *)attachment {
    NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: attachment.message];
    if (indexPath) {
        [self.tableView reloadRowsAtIndexPaths: @[indexPath] withRowAnimation: UITableViewRowAnimationFade];
    } else {
        attachment.uiDelegate = nil;
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
