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
#import "InsetImageView.h"
#import "MFSideMenu.h"
#import "UIViewController+HXOSideMenu.h"
#import "MessageCell.h"
#import "AutoheightLabel.h"
#import "HXOUserDefaults.h"
#import "ImageViewController.h"
#import "UserProfile.h"
#import "NSString+StringWithData.h"
#import "Vcard.h"
#import "NSData+Base64.h"
#import "Group.h"
#import "UIAlertView+BlockExtensions.h"
#import "TextMessageCell.h"
#import "ImageAttachmentMessageCell.h"
#import "GenericAttachmentMessageCell.h"
#import "ImageAttachmentWithTextMessageCell.h"
#import "GenericAttachmentWithTextMessageCell.h"
#import "ImageAttachmentSection.h"
#import "TextSection.h"
#import "GenericAttachmentSection.h"
#import "InsetImageView2.h"
#import "ProfileViewController.h"
#import "NickNameLabelWithStatus.h"
#import "HXOUpDownLoadControl.h"
#import "DateSectionHeaderView.h"
#import "MessageItems.h"
#import "HXOHyperLabel.h"

#define ACTION_MENU_DEBUG NO
#define DEBUG_ATTACHMENT_BUTTONS NO

static const NSUInteger kMaxMessageBytes = 10000;
static const CGFloat    kSectionHeaderHeight = 3 * 8;

typedef void(^AttachmentImageCompletion)(Attachment*, AttachmentSection*);

@interface ChatViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, readonly)  AttachmentPickerController* attachmentPicker;
@property (strong, nonatomic) UIView* attachmentPreview;
@property (nonatomic,strong) NSIndexPath * firstNewMessage;
@property (nonatomic,strong) NSMutableDictionary * cellPrototypes;
@property (strong, nonatomic) MPMoviePlayerViewController *  moviePlayerViewController;
@property (readonly, strong, nonatomic) ImageViewController * imageViewController;
@property (readonly, strong, nonatomic) ABUnknownPersonViewController * vcardViewController;
@property (nonatomic,strong) NickNameLabelWithStatus * titleLabel;

@property (strong, nonatomic) HXOMessage * messageToForward;

@property (nonatomic, readonly) NSMutableDictionary * messageItems;
@property (nonatomic, readonly) NSDateFormatter * dateFormatter;
@property (nonatomic, readonly) NSByteCountFormatter * byteCountFormatter;

@property (nonatomic) double messageFontSize;

@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
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

- (void)viewDidLoad {
    // NSLog(@"ChatViewController:viewDidLoad");
    [super viewDidLoad];
    self.messageFontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];

	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    
    [self.view bringSubviewToFront: _chatbar];

    _textField.delegate = self;
    _textField.backgroundColor = [UIColor clearColor];
    _textField.placeholder = NSLocalizedString(@"chat_view_message_placeholder", nil);

    UIView * textViewBackgroundView = [[UIImageView alloc] initWithFrame: CGRectInset(_textField.frame, 0, 2)];
    textViewBackgroundView.backgroundColor = [UIColor whiteColor];
    textViewBackgroundView.layer.cornerRadius = 6;
    textViewBackgroundView.layer.borderColor = [UIColor colorWithRed: 0.784 green: 0.784 blue: 0.804 alpha: 1].CGColor;
    textViewBackgroundView.layer.borderWidth = 1.0;
    textViewBackgroundView.clipsToBounds = YES;
    [_chatbar addSubview: textViewBackgroundView];
    textViewBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [_chatbar sendSubviewToBack: textViewBackgroundView];

    // setup longpress menus
    UIMenuController *menuController = [UIMenuController sharedMenuController];
    UIMenuItem *mySaveMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Save", nil) action:@selector(saveMessage:)];
    UIMenuItem *myDeleteMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", nil) action:@selector(deleteMessage:)];
    UIMenuItem *myResendMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Resend", nil) action:@selector(resendMessage:)];
    UIMenuItem *myForwardMessageMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", nil) action:@selector(forwardMessage:)];
    [menuController setMenuItems:@[mySaveMenuItem,myDeleteMessageMenuItem, myResendMessageMenuItem, myForwardMessageMenuItem]];
    [menuController update];
    
    [self hideAttachmentSpinner];
    [HXOBackend registerConnectionInfoObserverFor:self];

//    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
//    gestureRecognizer.cancelsTouchesInView = NO;
//    [self.tableView addGestureRecognizer:gestureRecognizer];

    [self registerCellClass: [TextMessageCell class]];
    [self registerCellClass: [ImageAttachmentMessageCell class]];
    [self registerCellClass: [GenericAttachmentMessageCell class]];
    [self registerCellClass: [ImageAttachmentWithTextMessageCell class]];
    [self registerCellClass: [GenericAttachmentWithTextMessageCell class]];
    [self.tableView registerClass: [DateSectionHeaderView class] forHeaderFooterViewReuseIdentifier: @"date_header"];

    self.titleLabel = [[NickNameLabelWithStatus alloc] init];
    self.navigationItem.titleView = self.titleLabel;
    self.titleLabel.label.textColor = [UIColor whiteColor];
    self.titleLabel.label.textAlignment = NSTextAlignmentCenter;

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"back_button_title", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    [self configureView];
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
    // NSLog(@"ChatViewController:viewWillAppear");
    [super viewWillAppear: animated];

    [self setNavigationBarBackgroundWithLines];
    [HXOBackend broadcastConnectionInfo];

    [self scrollToRememberedCellOrToBottomIfNone];
    [AppDelegate setWhiteFontStatusbarForViewController:self];
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
    // NSLog(@"ChatViewController:viewWillDisappear");
    [self rememberLastVisibleCell];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    _messageItems = nil;
}

- (void)configureView
{
    // NSLog(@"ChatViewController:configureView");
    // Update the user interface for the detail item.

    if (self.partner) {
        [self configureTitle];
    }
}

- (void) configureTitle {
    self.titleLabel.label.text = self.partner.nickNameWithStatus;
    self.titleLabel.isOnline = [self.partner.connectionStatus isEqualToString: @"online"];
    [self.titleLabel sizeToFit];
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

- (void)defaultsChanged:(NSNotification*)aNotification {
    // NSLog(@"defaultsChanged: object %@ info %@", aNotification.object, aNotification.userInfo);
    double fontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
    if (fontSize != self.messageFontSize) {
        self.messageFontSize = fontSize;
        [self updateVisibleCells];
        [self.tableView reloadData];
    }
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Contacts", @"Contacts Navigation Bar Title");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification*)aNotification {
    //NSLog(@"keyboardWasShown");
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    double duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat keyboardHeight = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ?  keyboardSize.height : keyboardSize.width;

    CGPoint contentOffset = self.tableView.contentOffset;
    contentOffset.y += keyboardHeight;

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.chatViewResizer.frame;
        frame.size.height -= keyboardHeight;
        self.chatViewResizer.frame = frame;
        self.tableView.contentOffset = contentOffset;
        // NSLog(@"keyboardWillShow did set table contentOffset y to %f", contentOffset.y);

    }];

    // this catches orientation changes, too
    _textField.maxHeight = _chatbar.frame.origin.y + _textField.frame.size.height - (self.navigationController.navigationBar.frame.origin.y  + self.navigationController.navigationBar.frame.size.height);
}

- (void)keyboardWillHide:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    CGFloat keyboardHeight = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ?  keyboardSize.height : keyboardSize.width;
    double duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.chatViewResizer.frame;
        frame.size.height += keyboardHeight;
        self.chatViewResizer.frame = frame;
    }];
}

- (void) hideKeyboard {
    [self.view endEditing: NO];
}

#pragma mark - Actions


- (IBAction)sendPressed:(id)sender {
    if ([self.partner.type isEqualToString:[Group entityName]]) {
        // check if there are other members in the group
        Group * group = (Group*)self.partner;
        if ([[group otherJoinedMembers] count] == 0) {
            // cant send message, no other joined members
            NSString * messageText;
            if ([[group otherInvitedMembers] count] > 0) {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"group_no_other_joined_partners_text", nil)];
            } else {
                messageText = [NSString stringWithFormat: NSLocalizedString(@"group_no_other_partner_text", nil)];
            }
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"group_no_other_partners_title", nil)
                                                             message: messageText
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            return;
        }

        if ([HXOBackend isInvalid:group.groupKey]) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"cant_send_no_groupkey_title", nil)
                                                             message: NSLocalizedString(@"cant_send_no_groupkey", nil)
                                                            delegate: nil
                                                   cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                                   otherButtonTitles: nil];
            [alert show];
            return;
            
        }
    } else if (![self.partner.relationshipState isEqualToString:@"friend"]) {
        NSString * messageText;
        if ([self.partner.relationshipState isEqualToString:@"blocked"]) {
            messageText = [NSString stringWithFormat: NSLocalizedString(@"cant_send_contact_blocked", nil)];
        } else {
            messageText = [NSString stringWithFormat: NSLocalizedString(@"cant_send_relationship_removed", nil)];
        }
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"cant_send_title", nil)
                                                         message: messageText
                                                        delegate: nil
                                               cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                               otherButtonTitles: nil];
        [alert show];
        return;
        
    }

    if (self.textField.text.length > 0 || self.attachmentPreview != nil) {
        if (self.currentAttachment == nil || self.currentAttachment.contentSize > 0) {
            if ([self.textField.text lengthOfBytesUsingEncoding: NSUTF8StringEncoding] > kMaxMessageBytes) {
                NSString * messageText = [NSString stringWithFormat: NSLocalizedString(@"message_too_long_text", nil), kMaxMessageBytes];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"message_too_long_title", nil)
                                                                 message: messageText
                                                                delegate: nil
                                                       cancelButtonTitle: NSLocalizedString(@"ok_button_title", nil)
                                                       otherButtonTitles: nil];
                [alert show];
                return;
            }
            if (self.currentAttachment != nil && [self.currentAttachment overTransferLimit:YES]) {
                NSString * attachmentSize = [NSString stringWithFormat:@"%1.03f MB",[self.currentAttachment.contentSize doubleValue]/1024/1024];
                NSString * message = [NSString stringWithFormat: NSLocalizedString(@"overlimit_attachment_upload_question",nil), attachmentSize];
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"overlimit_attachment_title", nil)
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
                                                       cancelButtonTitle: NSLocalizedString(@"message_do_not_send_button_title", nil)
                                                       otherButtonTitles: NSLocalizedString(@"message_send_button_title",nil),nil];
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
    [self.chatBackend sendMessage:self.textField.text toContactOrGroup:self.partner toGroupMemberOnly:nil withAttachment:self.currentAttachment];
    self.currentAttachment = nil;
    self.textField.text = @"";
    [self trashCurrentAttachment];
}

- (IBAction)addAttachmentPressed:(id)sender {
    // NSLog(@"addAttachmentPressed");
    [self.textField resignFirstResponder];
    [self.attachmentPicker showInView: self.view];
}

- (IBAction)attachmentPressed: (id)sender {
    // NSLog(@"attachmentPressed");
    [self.textField resignFirstResponder];
    [self showAttachmentOptions];
}

- (IBAction)cancelAttachmentProcessingPressed: (id)sender {
    // NSLog(@"cancelPressed");
    [self.textField resignFirstResponder];
    [self showAttachmentOptions];
}

#pragma mark - Attachments

- (AttachmentPickerController*) attachmentPicker {
    _attachmentPicker = [[AttachmentPickerController alloc] initWithViewController: self delegate: self];
    return _attachmentPicker;
}

+ (NSString *)sanitizeFileNameString:(NSString *)fileName {
    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    return [[fileName componentsSeparatedByCharactersInSet:illegalFileNameCharacters] componentsJoinedByString:@"_"];
}

+ (NSString *)uniqueFilenameForFilename: (NSString *)theFilename inDirectory: (NSString *)directory {
    
	if (![[NSFileManager defaultManager] fileExistsAtPath: [directory stringByAppendingPathComponent:theFilename]]) {
		return theFilename;
	};
	
	NSString *ext = [theFilename pathExtension];
	NSString *baseFilename = [theFilename stringByDeletingPathExtension];
	
	NSInteger i = 1;
	NSString* newFilename = [NSString stringWithFormat:@"%@_%@", baseFilename, [@(i) stringValue]];
    
    if ((ext == nil) || (ext.length <= 0)) {
        ext = @"";
        //NSLog(@"empty ext 3");
    }
	newFilename = [newFilename stringByAppendingPathExtension: ext];
	while ([[NSFileManager defaultManager] fileExistsAtPath: [directory stringByAppendingPathComponent:newFilename]]) {
		newFilename = [NSString stringWithFormat:@"%@_%@", baseFilename, [@(i) stringValue]];
		newFilename = [newFilename stringByAppendingPathExtension: ext];
		
		i++;
	}
	
	return newFilename;
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

+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint {
    
    NSString *newFileName = [ChatViewController sanitizeFileNameString: fileNameHint];
    NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
    NSString * myDocDir = [appDocDir path];
    NSString * myUniqueNewFile = [[self class]uniqueFilenameForFilename: newFileName inDirectory: myDocDir];
    NSString * savePath = [myDocDir stringByAppendingPathComponent: myUniqueNewFile];
    NSURL * myLocalURL = [NSURL fileURLWithPath:savePath];
    return myLocalURL;
}

- (void) didPickAttachment: (id) attachmentInfo {
    if (attachmentInfo == nil) {
        return;
    }
    [self startPickedAttachmentProcessingForObject:attachmentInfo];
    //NSLog(@"didPickAttachment: attachmentInfo = %@",attachmentInfo);

    self.currentAttachment = (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                        inManagedObjectContext: self.managedObjectContext];


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

        NSURL * myLocalURL = [ChatViewController uniqueNewFileURLForFileLike: @"location.json"];
        NSDictionary * json = @{ @"location": @{ @"type": @"point",
                                                 @"coordinates": @[ @(placemark.coordinate.longitude), @(placemark.coordinate.latitude)]},
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
            NSURL * myLocalURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
            
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
                NSURL * myLocalURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
                                
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

        NSURL * myExportURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
        
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
            NSString * myDescription = [NSString stringWithFormat:@"An audio export is still in progress"];
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
                UIImage * myImage = myOriginalImage;
                NSURL * myFileURL = nil;
                
                // create a lower quality image to attach dependend on quality settings
                if ([Attachment tooLargeImage:myImage]) {
                    myImage = [Attachment qualityAdjustedImage:myOriginalImage];
                    NSString * newFileName = @"reducedSnapshotImage.jpg";
                    myFileURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
                    
                    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                    [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myFileURL atomically:NO];
                }
                
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
                if ([Attachment tooLargeImage:myImage]) {
                    myImage = [Attachment qualityAdjustedImage:myImage];
                    NSString * newFileName = @"reducedSnapshotImage.jpg";
                    myURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
                    
                    float photoQualityCompressionSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoCompressionQuality"] floatValue];
                    [UIImageJPEGRepresentation(myImage,photoQualityCompressionSetting/10.0) writeToURL:myURL atomically:NO];
                }
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
            NSURL * myURL = attachmentInfo[UIImagePickerControllerReferenceURL];
            NSURL * myURL2 = attachmentInfo[UIImagePickerControllerMediaURL];

            // move file from temp directory to document directory
            NSString * newFileName = @"video.mov";
            NSURL * myNewURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
            NSError * myError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:myURL2 toURL:myNewURL error:&myError];
            if (myError != nil) {
                [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                return;
            }
            
            NSString *tempFilePath = [myNewURL path];
            if (myURL == nil) { // video was just recorded
                if ( UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(tempFilePath))
                {
                    UISaveVideoAtPathToSavedPhotosAlbum(tempFilePath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
                    NSLog(@"Saved new video at %@ to album",tempFilePath);
                } else {
                    NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: failed to save video in album at path = %@",tempFilePath];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 556 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    NSLog(@"%@", myDescription);
                    [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                    return;
                }
            }            
            
            NSString * myNewURLString = [myNewURL absoluteString];
            self.currentAttachment.ownedURL = myNewURLString;
            
            [self.currentAttachment makeVideoAttachment: myNewURLString anOtherURL: nil withCompletion:^(NSError *theError) {
                [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:theError];
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
    if (theImage != nil) {
        if (self.attachmentPreview != nil) {
            if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"decorateAttachmentButton: removeFromSuperview");
            [self.attachmentPreview removeFromSuperview];
        }
        //InsetImageView* preview = [[InsetImageView alloc] init];
        UIButton* preview = [[UIButton alloc] init];
        self.attachmentPreview = preview;
        preview.imageView.contentMode = UIViewContentModeScaleAspectFill;
        preview.frame = _attachmentButton.frame;
        //preview.image = theImage;
        [preview setImage:theImage forState:UIControlStateNormal];
        //preview.borderColor = [UIColor blackColor];
        //preview.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];
        //preview.backgroundColor = [UIColor blueColor];
        preview.autoresizingMask = _attachmentButton.autoresizingMask;
        [preview addTarget: self action: @selector(attachmentPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.chatbar addSubview: preview];
        _attachmentButton.hidden = YES;
    } else {
        if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"decorateAttachmentButton: removeAttachmentPreview");
        [self removeAttachmentPreview];
    }
}

- (void) removeAttachmentPreview {
    if (self.attachmentPreview != nil) {
        [self.attachmentPreview removeFromSuperview];
        self.attachmentPreview = nil;
        self.attachmentButton.hidden = NO;
    }
}

- (void) startPickedAttachmentProcessingForObject:(id)info {
    if (_currentAttachment != nil) {
        [self trashCurrentAttachment];
    }
    _currentPickInfo = info;
    // NSLog(@"startPickedAttachmentProcessingForObject:%@",_currentPickInfo);
    [self showAttachmentSpinner];
    _attachmentButton.hidden = YES;
    _sendButton.enabled = NO; // wait for attachment ready
}

- (void) finishPickedAttachmentProcessingWithImage:(UIImage*) theImage withError:(NSError*) theError {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage:%@ previewIcon:%@ withError:%@",theImage, self.currentAttachment.previewIcon, theError);
        _currentPickInfo = nil;
        [self hideAttachmentSpinner];
        if (theError == nil && theImage != nil) {
            if (theImage.size.height == 0) {
                if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with currentAttachment.previewIcon");
                [self decorateAttachmentButton:self.currentAttachment.previewIcon];
            } else {
                if (DEBUG_ATTACHMENT_BUTTONS)NSLog(@"finishPickedAttachmentProcessingWithImage: decorateAttachmentButton with theImage");
                [self decorateAttachmentButton:theImage];
            }
            _sendButton.enabled = YES;
        } else {
            if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"finishPickedAttachmentProcessingWithImage: trashCurrentAttachment");
            [self trashCurrentAttachment];
        }
    });
}

- (void) showAttachmentSpinner {
    if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"showAttachmentSpinner");
    _attachmentSpinner.hidden = NO;
    [_attachmentSpinner startAnimating];
}

- (void) hideAttachmentSpinner {
    if (DEBUG_ATTACHMENT_BUTTONS) NSLog(@"hideAttachmentSpinner");
    [_attachmentSpinner stopAnimating];
    _attachmentSpinner.hidden = YES;
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
        
        [self.managedObjectContext deleteObject: self.currentAttachment];
        self.currentAttachment = nil;
    }
    [self decorateAttachmentButton:nil];
    _attachmentButton.hidden = NO;
}

- (void) showAttachmentOptions {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"Attachment", @"Actionsheet Title")
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: NSLocalizedString(@"Remove Attachment", @"Actionsheet Button Title"),
                                                                  NSLocalizedString(@"Choose Attachment", @"Actionsheet Button Title"),
                                                                  NSLocalizedString(@"View Attachment", @"Actionsheet Button Title"),
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
            // Remove Attachment pressed
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


#pragma mark - Growing Text View Delegate

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height {
    float diff = (growingTextView.frame.size.height - height);

	CGRect r = _chatbar.frame;
    r.size.height -= diff;
    r.origin.y += diff;
	_chatbar.frame = r;

    r = self.tableView.frame;
    r.size.height += diff;
    self.tableView.frame = r;

    CGPoint contentOffset = self.tableView.contentOffset;
    contentOffset.y -= diff;
    self.tableView.contentOffset = contentOffset;

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
    HXOMessage * message = (HXOMessage*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    MessageCell *cell = [tableView dequeueReusableCellWithIdentifier: [self cellIdentifierForMessage: message] forIndexPath:indexPath];
    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    [self configureCell: cell forMessage: message];

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
    return kSectionHeaderHeight;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"tableView:didSelectRowAtIndexPath: %@",indexPath);
    HXOMessage * message = (HXOMessage*)[self.fetchedResultsController objectAtIndexPath: indexPath];

    if (message.attachment.available) {
        [self presentViewForAttachment: message.attachment];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
    MessageCell * cell = [_cellPrototypes objectForKey: [self cellIdentifierForMessage: message]];
    [self configureCell: cell forMessage: message];
    return [cell sizeThatFits: CGSizeMake(self.tableView.bounds.size.width, 10000)].height;
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

#pragma mark - Table view menu delegate


- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (ACTION_MENU_DEBUG) {NSLog(@"tableView:shouldShowMenuForRowAtIndexPath %@ - YES",indexPath);}
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    UIView * myCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if ([[myCell class] isKindOfClass:[MessageCell class]]) {
        if (ACTION_MENU_DEBUG) {NSLog(@"tableView::performAction:(%s):forRowAtIndexPath::withSender:sender ? - %@",sel_getName(action),(action == @selector(copy:))?@"YES":@"NO");}
        return (action == @selector(copy:));
    }
    if (ACTION_MENU_DEBUG) {NSLog(@"tableView::performAction:(%s):forRowAtIndexPath::withSender:sender - NO",sel_getName(action));}
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    UIView * myCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if (ACTION_MENU_DEBUG) {NSLog(@"tableView::performAction:(%s):forRowAtIndexPath::withSender:sender",sel_getName(action));}
    if ([[myCell class] isKindOfClass:[MessageCell class]]) {
        return YES;
    }
    return NO;
}


#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectContext == nil) {
        _managedObjectModel = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectModel;
    }
    return _managedObjectModel;
}


- (void) setPartner: (Contact*) partner {
    // NSLog(@"setPartner %@", partner.nickName);
    // NSLog(@"%@", [NSThread callStackSymbols]);
    if (_partner != nil) {
        [_partner removeObserver: self forKeyPath: @"nickName"];
        [_partner removeObserver: self forKeyPath: @"connectionStatus"];
    }
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
        [group addObserver: self forKeyPath: @"members" options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context: nil];
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

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath: @"timeSection" cacheName: [NSString stringWithFormat: @"Messages-%@", partner.objectID]];
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
    [self insertForwardedMessage];
}

- (void) addContactKVO: (Contact*) contact {
    [contact addObserver: self forKeyPath: @"nickName" options: NSKeyValueObservingOptionNew context: nil];
    [contact addObserver: self forKeyPath: @"connectionStatus" options: NSKeyValueObservingOptionNew context: nil];
    [contact addObserver: self forKeyPath: @"avatarImage" options: NSKeyValueObservingOptionNew context: nil];
}

- (void) removeContactKVO: (Contact*) contact {
    [contact removeObserver: self forKeyPath: @"nickName"];
    [contact removeObserver: self forKeyPath: @"connectionStatus"];
    [contact removeObserver: self forKeyPath: @"avatarImage"];
}

- (void) insertForwardedMessage {
    if (self.messageToForward) {
        // NSLog(@"insertForwardedMessage");
        self.textField.text = self.messageToForward.body;
        
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

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    //NSLog(@"observeValueForKeyPath %@ change %@", keyPath, change);
    //NSLog(@"%@", [NSThread callStackSymbols]);
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
        [self configureCell: (MessageCell*)[self.tableView cellForRowAtIndexPath:indexPath] forMessage: message];
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
            [self configureCell: (MessageCell*)[tableView cellForRowAtIndexPath:indexPath] forMessage: message];
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
    if ([message.isOutgoing isEqualToNumber: @YES]) {
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

- (void)configureCell:(MessageCell*)cell forMessage:(HXOMessage *) message {

    cell.delegate = self;

    if ([self viewIsVisible]){
        if ([message.isRead isEqualToNumber: @NO]) {
            // NSLog(@"configureCell setting isRead forMessage: %@", message.body);
            message.isRead = @YES;
            [self.managedObjectContext refreshObject: message.contact mergeChanges:YES];
        }
    }

    cell.colorScheme = [self colorSchemeForMessage: message];
    cell.messageDirection = [message.isOutgoing isEqualToNumber: @YES] ? HXOMessageDirectionOutgoing : HXOMessageDirectionIncoming;
    id author = [self getAuthor: message];
    UIImage * avatar = [author avatarImage] != nil ? [author avatarImage] : [UIImage imageNamed: @"avatar_default_contact"];
    [cell.avatar setImage: avatar forState: UIControlStateNormal];
    cell.avatar.showLed = [self.partner isKindOfClass: [Group class]] && ! [message.isOutgoing boolValue] && [[(Contact*)[message.deliveries.anyObject sender] connectionStatus] isEqualToString: @"online"];

    cell.subtitle.text = [self subtitleForMessage: message];


    for (MessageSection * section in cell.sections) {
        if ([section isKindOfClass: [TextSection class]]) {
            [self configureTextSection: (TextSection*)section forMessage: message];
        } else if ([section isKindOfClass: [ImageAttachmentSection class]]) {
            [self configureImageAttachmentSection: (ImageAttachmentSection*)section forMessage: message];
        } else if ([section isKindOfClass: [GenericAttachmentSection class]]) {
            [self configureGenericAttachmentSection: (GenericAttachmentSection*)section forMessage: message];
        }
    }
/*
    //NSLog(@"configureCell forMessage: %@", message.body);

    // TODO: clean up this shit...
    cell.fetchedResultsController = self.fetchedResultsController;

    //[self prepareLayoutOfCell: cell withMessage: message];


    cell.colorScheme = [self colorSchemeForMessage: message];
    cell.messageDirection = [message.isOutgoing isEqualToNumber: @YES] ? HXOMessageDirectionOutgoing : HXOMessageDirectionIncoming;

    id author = [self getAuthor: message];
    UIImage * avatar = [author avatarImage] != nil ? [author avatarImage] : [UIImage imageNamed: @"avatar_default_contact"];
    [cell.avatar setImage: avatar forState: UIControlStateNormal];
    cell.subtitle.text = [self.partner.type isEqualToString: @"Group"] ? [author nickName] : @"";


    if ([cell.reuseIdentifier isEqualToString: [CrappyTextMessageCell reuseIdentifier]]) {
        [self configureTextCell: (CrappyTextMessageCell*)cell forMessage: message];
    } else if ([cell.reuseIdentifier isEqualToString: [CrappyAttachmentMessageCell reuseIdentifier]]) {
        [self configureAttachmentCell: (CrappyAttachmentMessageCell*)cell forMessage: message];
    } else if ([cell.reuseIdentifier isEqualToString: [CrappyAttachmentWithTextMessageCell reuseIdentifier]]) {
        [self configureAttachmentCell: (CrappyAttachmentMessageCell*)cell forMessage: message];
        [self configureTextCell: cell forMessage: message];
    }
*/
}

- (void) configureTextSection: (TextSection*) section forMessage: (HXOMessage*) message {
    section.label.delegate = self;
    // maybe we find a better way to properly respond to font size changes
    section.label.font = [UIFont systemFontOfSize: self.messageFontSize];
    
    section.label.attributedText = [self getItemWithMessage: message].attributedBody;
}

- (void) configureAttachmentSection: (AttachmentSection*) section forMessage: (HXOMessage*) message {
    message.attachment.progressIndicatorDelegate = self;
    [section.upDownLoadControl addTarget: self action: @selector(didToggleTransfer:) forControlEvents: UIControlEventTouchUpInside];
    [self configureUpDownLoadControl: section.upDownLoadControl attachment: message.attachment];

    section.subtitle.text = [self attachmentSubtitle: message.attachment];

}

- (void) configureUpDownLoadControl: (HXOUpDownLoadControl*) upDownLoadControl attachment: (Attachment*) attachment{
    upDownLoadControl.hidden = attachment.available && attachment.state == kAttachmentTransfered;
    BOOL isActive = [self attachmentIsActive: attachment];
    upDownLoadControl.selected = isActive;
    if (attachment.state == kAttachmentWantsTransfer || attachment.state == kAttachmentTransferScheduled) {
        [upDownLoadControl startSpinning];
    }
}

- (void) configureGenericAttachmentSection: (GenericAttachmentSection*) section forMessage: (HXOMessage*) message {
    [self configureAttachmentSection: section forMessage: message];


    [self loadAttachmentImage: message.attachment withSection: section completion:^(Attachment * attachment, AttachmentSection * section) {
        if ([section isKindOfClass: [GenericAttachmentSection class]]) {
            GenericAttachmentSection * attachmentSection = (GenericAttachmentSection*)section;

            if (attachment.previewImage.size.height != 0 && attachment.state == kAttachmentTransfered) {
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
    }];

    NSString * title = message.attachment.humanReadableFileName;
    if (title == nil || [title isEqualToString: @""]) {

    }
    section.title.text = [self attachmentTitle: message];
}

- (void) configureImageAttachmentSection: (ImageAttachmentSection*) section forMessage: (HXOMessage*) message {
    [self configureAttachmentSection: section forMessage: message];
    section.imageAspect = message.attachment.aspectRatio;

    [self loadAttachmentImage: message.attachment withSection: section completion:^(Attachment * attachment, AttachmentSection * section) {
        if ([section isKindOfClass: [ImageAttachmentSection class]]) {
            ImageAttachmentSection * imageSection = (ImageAttachmentSection*)section;
            if (attachment.previewImage.size.height != 0 && attachment.state == kAttachmentTransfered) {
                imageSection.image = message.attachment.previewImage;
            } else {
                imageSection.image = nil;
            }
            imageSection.subtitle.hidden = imageSection.image != nil;
            imageSection.showPlayButton = [attachment.mediaType isEqualToString: @"video"] && imageSection.image != nil;
        }
    }];
}


- (void) loadAttachmentImage: (Attachment*) attachment withSection: (AttachmentSection*) section completion: (AttachmentImageCompletion) completion {

    if (attachment.previewImage == nil && attachment.available) {
        [attachment loadPreviewImageIntoCacheWithCompletion:^(NSError *theError) {
            if (theError == nil) {
                NSIndexPath * indexPath = [self.fetchedResultsController indexPathForObject: attachment.message];
                if (indexPath) {
                    AttachmentSection * section = [((id)[self.tableView cellForRowAtIndexPath: indexPath]) attachmentSection];
                    if (section) {
                        completion(attachment, section);
                    }
                }
            } else {
                NSLog(@"ERROR: Failed to load attachment preview image: %@", theError);
            }
        }];
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
                if (message.isOutgoing.boolValue) {
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

- (HXOBubbleColorScheme) colorSchemeForMessage: (HXOMessage*) message {

    if ([message.isOutgoing isEqualToNumber: @NO]) {
        return HXOBubbleColorSchemeIncoming;
    }

    if ([message.deliveries count] > 1) {
        NSLog(@"WARNING: NOT YET IMPLEMENTED: delivery status for multiple deliveries");
    }
    for (Delivery * myDelivery in message.deliveries) {
        if ([myDelivery.state isEqualToString:kDeliveryStateNew] ||
            [myDelivery.state isEqualToString:kDeliveryStateDelivering])
        {
            return HXOBubbleColorSchemeInProgress;
        } else if ([myDelivery.state isEqualToString:kDeliveryStateDelivered] ||
                   [myDelivery.state isEqualToString:kDeliveryStateConfirmed])
        {
            return HXOBubbleColorSchemeSuccess;
        } else if ([myDelivery.state isEqualToString:kDeliveryStateFailed]) {
            return HXOBubbleColorSchemeFailed;
        } else {
            NSLog(@"ERROR: unknow delivery state %@", myDelivery.state);
        }
    }
    return HXOBubbleColorSchemeSuccess;
}

- (NSString*) stateStringForMessage: (HXOMessage*) message {

    if ([message.deliveries count] > 1) {
        NSLog(@"WARNING: NOT YET IMPLEMENTED: delivery status for multiple deliveries");
    }

    for (Delivery * myDelivery in message.deliveries) {
        if ([myDelivery.state isEqualToString:kDeliveryStateNew]) {
            return NSLocalizedString(@"message_pending", nil);
        } else if ([myDelivery.state isEqualToString:kDeliveryStateDelivering] ||
                   [myDelivery.state isEqualToString:kDeliveryStateDelivered])
        {
            return NSLocalizedString(@"message_sent", nil);
        } else if ([myDelivery.state isEqualToString:kDeliveryStateConfirmed]) {
            return NSLocalizedString(@"message_delivered", nil);
        } else if ([myDelivery.state isEqualToString:kDeliveryStateFailed]) {
            return NSLocalizedString(@"message_failed", nil);
        /* TODO } else if () {
             return NSLocalizedString(@"message_read", nil); */
        } else {
            NSLog(@"ERROR: unknow delivery state %@", myDelivery.state);
        }
    }
    return @"";
}

- (NSString*) subtitleForMessage: (HXOMessage*) message {
    if ([message.isOutgoing isEqualToNumber: @YES]) {
        return [self stateStringForMessage: message];
    } else {
        return message.contact.nickName;
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
    BOOL isOutgoing = [message.isOutgoing isEqualToNumber: @YES];
    BOOL isComplete = [attachment.transferSize isEqualToNumber: attachment.contentSize];

    // TODO: some of this stuff is quite expensive: reading vcards, loading audio metadata, &c.
    // It is probably a good idea to cache the attachment titles in the database.
    NSString * title;
    if (isComplete || isOutgoing) {
        if ([attachment.mediaType isEqualToString: @"vcard"]) {
            title = item.vcardName;
        } else if ([attachment.mediaType isEqualToString: @"geolocation"]) {
            title = NSLocalizedString(@"location_default_title", nil);
        } else if ([attachment.mediaType isEqualToString: @"audio"]) {
            NSRange findResult = [message.attachment.humanReadableFileName rangeOfString:@"recording"];
            if ( ! (findResult.length == @"recording".length && findResult.location == 0)) {
                title = item.audioTitle;
            }
        }
    } else if (message.attachment.state == kAttachmentTransferOnHold) {
        NSString * name = message.attachment.humanReadableFileName != nil ? message.attachment.humanReadableFileName : NSLocalizedString(message.attachment.mediaType, nil);
        title = name;
    }

    if (title == nil) {
        title = attachment.humanReadableFileName;
    }
    return title;
}

- (NSString*) attachmentSubtitle: (Attachment*) attachment {

    MessageItem * item = [self getItemWithMessage: attachment.message];
    NSString * fileSize = [self.byteCountFormatter stringFromByteCount: [attachment.contentSize longLongValue]];
    NSString * sizeString;
    if ([attachment.contentSize longLongValue] == [attachment.transferSize longLongValue]) {
        sizeString = fileSize;
    } else {
        NSString * currentSize = [self.byteCountFormatter stringFromByteCount: [attachment.transferSize longLongValue]];
        sizeString = [NSString stringWithFormat: @"%@ / %@", currentSize, fileSize];
    }

    if (attachment.state == kAttachmentTransferOnHold) {
        NSString * question = attachment.message.isOutgoing.boolValue ? @"upload_question" : @"download_question";
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
        NSString * name = attachment.humanReadableFileName != nil ? attachment.humanReadableFileName : NSLocalizedString(attachment.mediaType, nil);
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
    // NSLog(@"messageCell:canPerformAction:");
    if (action == @selector(deleteMessage:)) return YES;
    if (action == @selector(copy:)) {return YES;}

    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];

    if (action == @selector(copy:)) {return YES;}
#ifdef DEBUG
    if (action == @selector(resendMessage:)) {return YES;}
#endif
    if (action == @selector(forwardMessage:)) {return YES;}
    
    if (action == @selector(saveMessage:)) {
        if ([message.isOutgoing isEqualToNumber: @NO], YES) {
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
    for (int i = 0; i < 10;++i) {
        [self.chatBackend forwardMessage: message.body toContactOrGroup:message.contact toGroupMemberOnly:nil withAttachment:message.attachment];
    }
}

- (void) messageCell:(MessageCell *)theCell forwardMessage:(id)sender {
    //NSLog(@"forwardMessage");
    self.messageToForward = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self.menuContainerViewController toggleRightSideMenuCompletion:^{}];
    // [self.chatBackend forwardMessage: message.body toContact:message.contact withAttachment:message.attachment];
}

- (void) messageCell:(MessageCell *)theCell saveMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    Attachment * attachment = message.attachment;
    if (attachment != nil) {
        [attachment trySaveToAlbum];
    }

}

- (void) messageCell:(MessageCell *)theCell copy:(id)sender {
    // NSLog(@"copy");
    UIPasteboard * board = [UIPasteboard generalPasteboard];
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];

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
    
    [self.managedObjectContext deleteObject: message];
    [self.chatBackend.delegate saveDatabase];
    
}

- (void) messageCellDidPressAvatar:(MessageCell *)cell {
    ProfileViewController * profileViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"profileViewController"];

    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell: cell]];
    
    if ([message.isOutgoing isEqualToNumber: @NO]) {
        if ([message.contact.type isEqualToString:[Group entityName]]) {
            profileViewController.contact = [message.deliveries.anyObject sender];
        } else {
            profileViewController.contact = message.contact;
        }
    } else {
        profileViewController.contact = nil;
    }

    [self.navigationController pushViewController: profileViewController animated: YES];
}

- (void) presentViewForAttachment:(Attachment *) myAttachment {
    if ([myAttachment.mediaType isEqual: @"video"]) {
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
                        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([coordinates[1] doubleValue], [coordinates[0] doubleValue]);
                        MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate
                                                                       addressDictionary:nil];
                        MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
                        [mapItem setName:NSLocalizedString(@"The Place",@"placemark name")];
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

- (void) scrollToCell:(NSIndexPath*)theCell {
    // save index path of bottom most visible cell
    //NSLog(@"scrollToCell %@", theCell);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    [self.tableView scrollToRowAtIndexPath: self.partner.rememberedLastVisibleChatCell atScrollPosition:UITableViewScrollPositionBottom animated: NO];
}

- (void) scrollToRememberedCellOrToBottomIfNone {
    if (self.partner.rememberedLastVisibleChatCell != nil) {
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
    [self removeContactKVO: self.partner];
    if ([self.partner isKindOfClass: [Group class]]) {
        Group * group = (Group*) self.partner;
        [group.members enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            Contact * contact = [obj contact];
            if (contact != nil) {
                [self removeContactKVO: contact];
            }
        }];
        [group removeObserver: self forKeyPath: @"members"];
    }
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
                                           cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                           otherButtonTitles: NSLocalizedString(@"button_title_call", nil), nil];
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

@end
