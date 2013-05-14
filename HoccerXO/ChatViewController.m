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
#import "UIViewController+HXOSideMenuButtons.h"
#import "ChatTableCells.h"
#import "AutoheightLabel.h"
#import "Attachment.h"
#import "AttachmentViewFactory.h"
#import "BubbleView.h"
#import "HXOUserDefaults.h"
#import "ImageViewController.h"
#import "UserProfile.h"
#import "NSString+StringWithData.h"
#import "Vcard.h"
#import "NSData+Base64.h"

#define ACTION_MENU_DEBUG NO

static const NSUInteger kMaxMessageBytes = 10000;
static const CGFloat    kSectionHeaderHeight = 40;

@interface ChatViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, nonatomic) UIView* attachmentPreview;
@property (nonatomic,strong) NSIndexPath * firstNewMessage;
@property (nonatomic, readonly) MessageCell* messageCell;
@property (strong) UIImage* avatarImage;
@property (strong, nonatomic) MPMoviePlayerViewController *  moviePlayerViewController;
@property (readonly, strong, nonatomic) ImageViewController * imageViewController;
@property (readonly, strong, nonatomic) ABUnknownPersonViewController * vcardViewController;

@property (strong, nonatomic) HXOMessage * messageToForward;

// @property (strong, nonatomic) NSIndexPath * rememberedVisibleCell;

- (void)configureCell:(UITableViewCell *)cell forMessage:(HXOMessage *) message;
- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;
@synthesize messageCell = _messageCell;
@synthesize moviePlayerViewController = _moviePlayerViewController;
@synthesize imageViewController = _imageViewController;
@synthesize vcardViewController = _vcardViewController;
@synthesize currentExportSession = _currentExportSession;
@synthesize currentPickInfo = _currentPickInfo;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    [self.view bringSubviewToFront: _chatbar];

    UIColor * barBackground = [UIColor colorWithPatternImage: [UIImage imageNamed: @"chatbar_bg_noise"]];
    _chatbar.backgroundColor = barBackground;

    UIImage * backgroundGradientImage = [UIImage imageNamed: @"chatbar_bg_gradient"];
    if ([backgroundGradientImage respondsToSelector: @selector(resizableImageWithCapInsets:resizingMode:)]) {
        backgroundGradientImage = [backgroundGradientImage resizableImageWithCapInsets:UIEdgeInsetsMake(2, 0, 0, 0) resizingMode: UIImageResizingModeStretch];
    } else {
        backgroundGradientImage = [backgroundGradientImage stretchableImageWithLeftCapWidth:0 topCapHeight:12];
    }
    UIImageView * backgroundGradient = [[UIImageView alloc] initWithImage: backgroundGradientImage];

    backgroundGradient.frame = _chatbar.bounds;
    [_chatbar addSubview: backgroundGradient];
    backgroundGradient.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    _textField.delegate = self;
    _textField.backgroundColor = [UIColor clearColor];
    CGRect frame = _textField.frame;
    CGRect bgframe = _textField.frame;
    frame.size.width -= 6;
    frame.origin.x += 3;
    _textField.frame = frame;

    UIImage *textfieldBackground = [[UIImage imageNamed:@"chatbar_input-text"] stretchableImageWithLeftCapWidth:14 topCapHeight:14];
    UIImageView * textViewBackgroundView = [[UIImageView alloc] initWithImage: textfieldBackground];
    [_chatbar addSubview: textViewBackgroundView];
    bgframe.origin.y -= 3;
    bgframe.size.height = 30;
    textViewBackgroundView.frame = bgframe;
    textViewBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // TODO: make the send button image smaller
    UIImage *sendButtonBackground = [[UIImage imageNamed:@"chatbar_btn-send"] stretchableImageWithLeftCapWidth:25 topCapHeight:0];
    [self.sendButton setBackgroundImage: sendButtonBackground forState: UIControlStateNormal];
    [self.sendButton setBackgroundColor: [UIColor clearColor]];
    self.sendButton.titleLabel.shadowOffset  = CGSizeMake(0.0, -1.0);
    [self.sendButton setTitleShadowColor:[UIColor colorWithWhite: 0 alpha: 0.4] forState:UIControlStateNormal];

    // Ok, we don't want to do this to often but let's relayout the chatbar for the localized send button title
    frame = self.sendButton.frame;
    CGFloat initialTitleWidth = _sendButton.titleLabel.frame.size.width;
    [_sendButton setTitle: NSLocalizedString(@"Send", @"Chat Send Button Title") forState: UIControlStateNormal];
    CGFloat newTitleWidth = [_sendButton.titleLabel.text sizeWithFont: self.sendButton.titleLabel.font].width;
    CGFloat dx = newTitleWidth - initialTitleWidth;
    frame.origin.x -= dx;
    frame.size.width += dx;
    _sendButton.frame = frame;
    frame = _textField.frame;
    frame.size.width -= dx;
    _textField.frame = frame;
    frame = textViewBackgroundView.frame;
    frame.size.width -= dx;
    textViewBackgroundView.frame = frame;

    [_chatbar sendSubviewToBack: textViewBackgroundView];
    [_chatbar sendSubviewToBack: backgroundGradient];

    self.view.backgroundColor = [UIColor colorWithPatternImage: [self radialGradient]];
    
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
    
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.partner) {
        // self.title = self.partner.nickName;
        self.title = self.partner.nickNameWithStatus;
    }
}

- (HXOBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
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

#pragma mark - Keyboard events

// TODO: correctly handle orientation changes while keyboard is visible

- (void)keyboardWasShown:(NSNotification*)aNotification {
    //NSLog(@"keyboardWasShown");
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    double duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat keyboardHeight = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ?  keyboardSize.height : keyboardSize.width;

    CGPoint contentOffset = self.tableView.contentOffset;
    contentOffset.y += keyboardHeight;

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.view.frame;
        frame.size.height -= keyboardHeight;
        self.view.frame = frame;
        self.tableView.contentOffset = contentOffset;
        // NSLog(@"keyboardWasShown did set table contentOffset y to %f", contentOffset.y);
    }];

    // this catches orientation changes, too
    _textField.maxHeight = _chatbar.frame.origin.y + _textField.frame.size.height;
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    CGFloat keyboardHeight = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ?  keyboardSize.height : keyboardSize.width;
    double duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.view.frame;
        frame.size.height += keyboardHeight;
        self.view.frame = frame;
    }];
}

#pragma mark - Actions

- (IBAction)sendPressed:(id)sender {
    [self.textField resignFirstResponder];
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
            [self.chatBackend sendMessage: self.textField.text toContact: self.partner withAttachment: self.currentAttachment];
            self.currentAttachment = nil;
            self.textField.text = @"";
        } else {
            // attachment content processing in progess, probably audio export
            NSLog(@"ERROR: sendPressed called while attachment not ready, should not happen");
            return;
        }
    }
    [self trashCurrentAttachment]; // will be trashed only in case it is still set
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
//    if (_attachmentPicker == nil) {
        _attachmentPicker = [[AttachmentPickerController alloc] initWithViewController: self delegate: self];
        
//    }
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
        MKPlacemark * placemark = attachmentInfo[@"com.hoccer.xo.geolocation"];
        NSLog(@"got geolocation %f %f", placemark.coordinate.latitude, placemark.coordinate.longitude);

        UIImage * preview = attachmentInfo[@"com.hoccer.xo.previewImage"];
        NSData * previewData = UIImageJPEGRepresentation( preview, 1.0);

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
                [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:myerror];
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
                [UIImageJPEGRepresentation(myImage,1.0) writeToURL:myLocalURL atomically:NO];
                                
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
        
        [_currentExportSession exportAsynchronouslyWithCompletionHandler:^{
            int exportStatus = _currentExportSession.status;
            switch (exportStatus) {
                case AVAssetExportSessionStatusFailed: {
                    // log error to text view
                    NSString * myDescription = [NSString stringWithFormat:@"Audio export failed (AVAssetExportSessionStatusFailed)"];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 559 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    _currentExportSession = nil;
                    [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                    break;
                }
                case AVAssetExportSessionStatusCompleted: {
                    // NSLog (@"AVAssetExportSessionStatusCompleted");
                    [self.currentAttachment makeAudioAttachment: [assetURL absoluteString] anOtherURL:[_currentExportSession.outputURL absoluteString] withCompletion:^(NSError *theError) {
                        _currentExportSession = nil;
                        self.currentAttachment.humanReadableFileName = [myExportURL lastPathComponent];
                        [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:theError];
                    }];
                     // TODO: in case we fail getting the artwork from file try get artwork from Media Item
                     // set up artwork image
                     // MPMediaItemArtwork * artwork = [song valueForProperty:MPMediaItemPropertyArtwork];
                     // NSLog(@"createThumb1: artwork=%@", artwork);
                     // UIImage * artworkImage = [artwork imageWithSize:CGSizeMake(400,400)];
                    
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
                UIImage * myImage = [Attachment qualityAdjustedImage:attachmentInfo[UIImagePickerControllerOriginalImage]];
                
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        myURL = assetURL;

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
                
                if(myImage) {
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [library writeImageToSavedPhotosAlbum:[myImage CGImage]
                                              orientation:(ALAssetOrientation)[myImage imageOrientation]
                                          completionBlock:completeBlock];
                }
            } else {
                // image from album
                UIImage * myImage = attachmentInfo[UIImagePickerControllerOriginalImage];
                if ([Attachment tooLargeImage:myImage]) {
                    myImage = [Attachment qualityAdjustedImage:myImage];
                    NSString * newFileName = @"reducedSnapshotImage.jpg";
                    NSURL * myURL = [ChatViewController uniqueNewFileURLForFileLike:newFileName];
                    
                    [UIImageJPEGRepresentation(myImage,0.9) writeToURL:myURL atomically:NO];
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
            NSString *tempFilePath = [myURL2 path];
            if (myURL == nil) { // video was just recorded
                if ( UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(tempFilePath))
                {
                    UISaveVideoAtPathToSavedPhotosAlbum(tempFilePath, nil, nil, nil);
                    NSString * myTempURL = [myURL2 absoluteString];
                    // NSLog(@"video myTempURL = %@", myTempURL);
                    self.currentAttachment.ownedURL = [myTempURL copy];
                } else {
                    NSString * myDescription = [NSString stringWithFormat:@"didPickAttachment: failed to save video in album at path = %@",tempFilePath];
                    NSError * myError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 556 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                    [self finishPickedAttachmentProcessingWithImage:nil withError:myError];
                    return;
                }
            }
            [self.currentAttachment makeVideoAttachment: [myURL2 absoluteString] anOtherURL: nil withCompletion:^(NSError *theError) {
                [self finishPickedAttachmentProcessingWithImage: self.currentAttachment.previewImage withError:theError];
            }];
            return;
        }
    }
    // Do not do anything here because some functions above will finish asynchronously
    // just in case, but we should never get here
    [self finishPickedAttachmentProcessingWithImage: nil withError:nil];
}

- (void) decorateAttachmentButton:(UIImage *) theImage {
    // NSLog(@"decorateAttachmentButton with %@", theImage);
    if (theImage != nil) {
        if (self.attachmentPreview != nil) {
            [self.attachmentPreview removeFromSuperview];
        }
        InsetImageView* preview = [[InsetImageView alloc] init];
        self.attachmentPreview = preview;
        preview.frame = _attachmentButton.frame;
        preview.image = theImage;
        preview.borderColor = [UIColor blackColor];
        preview.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];
        preview.autoresizingMask = _attachmentButton.autoresizingMask;
        [preview addTarget: self action: @selector(attachmentPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.chatbar addSubview: preview];
        _attachmentButton.hidden = YES;
    } else {
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
    _currentPickInfo = info;
    // NSLog(@"startPickedAttachmentProcessingForObject:%@",_currentPickInfo);
    [self showAttachmentSpinner];
    _attachmentButton.hidden = YES;
}

- (void) finishPickedAttachmentProcessingWithImage:(UIImage*) theImage withError:(NSError*) theError {
    // NSLog(@"finishPickedAttachmentProcessingWithImage:%@ withError:%@",theImage, theError);
    _currentPickInfo = nil;
    [self hideAttachmentSpinner];
    if (theError == nil && theImage != nil) {
        [self decorateAttachmentButton:theImage];
    } else {
        [self trashCurrentAttachment];
    }
}

- (void) showAttachmentSpinner {
    // NSLog(@"showAttachmentSpinner");
    _attachmentSpinner.hidden = NO;
    [_attachmentSpinner startAnimating];
}

- (void) hideAttachmentSpinner {
    // NSLog(@"hideAttachmentSpinner");
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
            [self presentViewForAttachment: self.currentAttachment];
            // NSLog(@"Viewing current attachment");
            break;
        default:
            break;
    }
}


#pragma mark - Growing Text View Delegate

- (void)growingTextView:(GrowingTextView *)growingTextView willChangeHeight:(float)height {
    float diff = (growingTextView.frame.size.height - height);

	CGRect r = _chatbar.frame;
    r.size.height -= diff;
    r.origin.y += diff;
	_chatbar.frame = r;
}

#pragma mark - Graphics Utilities

- (UIImage *)radialGradient {
    CGSize size = self.tableView.frame.size;
    CGPoint center = CGPointMake(0.5 * size.width, 0.5 * size.height) ;

    UIGraphicsBeginImageContextWithOptions(size, YES, 1);

    // Drawing code
    CGContextRef cx = UIGraphicsGetCurrentContext();

    CGContextSaveGState(cx);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    CGFloat comps[] = {1.0,1.0,1.0,1.0,
        0.9,0.9,0.9,1.0};
    CGFloat locs[] = {0,1};
    CGGradientRef g = CGGradientCreateWithColorComponents(space, comps, locs, 2);

    CGContextDrawRadialGradient(cx, g, center, 0.0f, center, size.width > size.height ? 0.5 * size.width : 0.5 * size.height, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
    CGColorSpaceRelease(space); // added by pm because analyzer leak waring

    CGContextRestoreGState(cx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    return image;
}

- (MessageCell*) messageCell {
    if (_messageCell == nil) {
        _messageCell = [self.tableView dequeueReusableCellWithIdentifier: [LeftMessageCell reuseIdentifier]];
    }
    return _messageCell;
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

    NSString * identifier = [message.isOutgoing isEqualToNumber: @YES] ? [RightMessageCell reuseIdentifier] : [LeftMessageCell reuseIdentifier];
    
    MessageCell *cell = [tableView dequeueReusableCellWithIdentifier: identifier forIndexPath:indexPath];
    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    cell.delegate = self;
    [self configureCell: cell forMessage: message];

    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView * header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, kSectionHeaderHeight)];

    UIImage * backgroundImage = [UIImage imageNamed: @"date_cell_bg"];
    CGFloat y = 0.5 * (kSectionHeaderHeight - backgroundImage.size.height);
    UIImageView * background = [[UIImageView alloc] initWithFrame: CGRectMake(0, y, 320, backgroundImage.size.height)];
    background.image = backgroundImage;
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview: background];

    UILabel * label = [[UILabel alloc] initWithFrame: header.frame];
    label.backgroundColor = [UIColor clearColor];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.textAlignment = NSTextAlignmentCenter;
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    label.textColor = [UIColor colorWithWhite: 0.33 alpha: 1.0];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake(0, 1);
    label.font = [UIFont boldSystemFontOfSize: 9];
    [header addSubview: label];

    return header;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    
    NSArray *objects = [sectionInfo objects];
    NSManagedObject *managedObject = objects[0];
    NSDate *timeSection = (NSDate *)[managedObject valueForKey:@"timeSection"];
    // NSLog(@"titleForHeaderInSection: timeSection = %@",timeSection);
    return [Contact sectionTitleForMessageTime:timeSection];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return kSectionHeaderHeight;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"tableView:shouldShowMenuForRowAtIndexPath %@",indexPath);
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    double width = self.tableView.frame.size.width;

    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];

    CGRect frame = self.messageCell.frame;
    self.messageCell.frame = CGRectMake(frame.origin.x, frame.origin.y, width, frame.size.height);

    CGFloat myHeight = [self.messageCell heightForMessage: message];
    // NSLog(@"tableView:heightForRowAtIndexPath: %@ returns %f", indexPath, myHeight);
    return myHeight;
}


//- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//    NSLog(@"scrollViewDidEndDecelerating:");
//    NSLog(@"contentOffset: %f %f", scrollView.contentOffset.x, scrollView.contentOffset.y);
//}
//
//- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
//    NSLog(@"scrollViewDidEndScrollingAnimation:");
//    NSLog(@"contentOffset: %f %f", scrollView.contentOffset.x, scrollView.contentOffset.y);
//}
//
//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    NSLog(@"scrollViewDidScroll:");
//    NSLog(@"contentOffset: %f %f", scrollView.contentOffset.x, scrollView.contentOffset.y);
//}

#pragma mark - Table view menu delegate


- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (ACTION_MENU_DEBUG) {NSLog(@"tableView:shouldShowMenuForRowAtIndexPath %@",indexPath);}
    UIView * myCell = [self.tableView cellForRowAtIndexPath:indexPath];
    if ([[myCell class] isKindOfClass:[ChatTableSectionHeaderCell class]]) {
        if (ACTION_MENU_DEBUG) {NSLog(@"tableView:shouldShowMenuForRowAtIndexPath %@ - NO",indexPath);}
        return NO;
    }
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
    if (_partner != nil) {
        [_partner removeObserver: self forKeyPath: @"nickName"];
        [_partner removeObserver: self forKeyPath: @"connectionStatus"];
    }
    _partner = partner;
    if (partner == nil) {
        return;
    }
    [_partner addObserver: self forKeyPath: @"nickName" options: NSKeyValueObservingOptionNew context: nil];
    [_partner addObserver: self forKeyPath: @"connectionStatus" options: NSKeyValueObservingOptionNew context: nil];
    [_partner addObserver: self forKeyPath: @"avatarImage" options: NSKeyValueObservingOptionNew context: nil];

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
    [self scrollToRememberedCellOrToBottomIfNone];
    [self configureView];
    [self insertForwardedMessage];
}

- (void) insertForwardedMessage {
    if (self.messageToForward) {
        NSLog(@"insertForwardedMessage");
        self.textField.text = self.messageToForward.body;
        
        if (self.currentAttachment) {
            [self trashCurrentAttachment];
        }
        
        AttachmentCompletionBlock completion  = ^(Attachment * myAttachment, NSError *myerror) {
            self.currentAttachment = myAttachment;
            NSLog(@"insertForwardedMessage: self.currentAttachment=%@",self.currentAttachment);
            [self finishPickedAttachmentProcessingWithImage: myAttachment.previewImage withError:myerror];
        };
        [self.chatBackend cloneAttachment:self.messageToForward.attachment whenReady:completion];
        self.messageToForward = nil;
    }
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString: @"nickName"] ||
        [keyPath isEqualToString: @"connectionStatus"]) {
        // self.title = [object nickName];
        self.title = [object nickNameWithStatus];
    } else if ([keyPath isEqualToString: @"avatarImage"]) {
        NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
        [self.tableView beginUpdates];
        for (int i = 0; i < indexPaths.count; ++i) {
            NSIndexPath * indexPath = indexPaths[i];
            HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] forMessage: message];
        }
        [self.tableView endUpdates];
    }
}

#pragma mark - NSFetchedResultsController delegate methods


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            // NSLog(@"didChangeObject insert");
            if (self.firstNewMessage == nil) {
                self.firstNewMessage = newIndexPath;
                // NSLog(@"didChangeObject insert: set firstNewMessage indexPath=%@", newIndexPath);
            }
            break;
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
        {
            HXOMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] forMessage: message];
            break;
        }

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
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


- (void) viewWillAppear:(BOOL)animated {
    // NSLog(@"ChatViewController:viewWillAppear");
    [super viewWillAppear: animated];

    [self setNavigationBarBackgroundWithLines];
    if (self.fetchedResultsController != nil) {
        self.fetchedResultsController.delegate = self;
    }
    [HXOBackend broadcastConnectionInfo];

    [self scrollToRememberedCellOrToBottomIfNone];
}


- (void) viewWillDisappear:(BOOL)animated {
    // [self trashCurrentAttachment];

    [self rememberLastVisibleCell];

    if (self.fetchedResultsController != nil) {
        self.fetchedResultsController.delegate = nil;
    }

}

- (void)configureCell:(MessageCell *)cell forMessage:(HXOMessage *) message {

    if (self.avatarImage == nil) {
        UIImage * myImage = [UserProfile sharedProfile].avatarImage;
        self.avatarImage = myImage != nil ? myImage : [UIImage imageNamed: @"avatar_default_contact"];
    }

    if ([message.isRead isEqualToNumber: @NO]) {
        message.isRead = @YES;
        [self.managedObjectContext refreshObject: message.contact mergeChanges:YES];
    }

    cell.message.text = message.body;
    UIImage * avatar = [message.isOutgoing isEqualToNumber: @YES] ? self.avatarImage : self.partner.avatarImage;
    avatar = avatar != nil ? avatar : [UIImage imageNamed: @"avatar_default_contact"];

    cell.avatar.image = avatar;

    // cell.cellOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    // cell.bubble.frame = [cell.bubble bubbleFrameForCellFrame:cell.frame];
    cell.bubble.frame = [cell.bubble bubbleFrameForMessage:message inCellWithWidth:cell.frame.size.width];
    [cell.bubble setNeedsLayout];
    [cell.bubble layoutIfNeeded];
    
    // NSLog(@"configureCell BubbleView %x attachment %x time=%@",(int)(__bridge void*)cell.bubble, (int)(__bridge void*)message.attachment, message.timeAccepted);

    if (message.attachment &&
        ([message.attachment.mediaType isEqualToString:@"image"] ||
         [message.attachment.mediaType isEqualToString:@"video"] ||
         [message.attachment.mediaType isEqualToString:@"vcard"] ||
         [message.attachment.mediaType isEqualToString:@"geolocation"] ||
         [message.attachment.mediaType isEqualToString:@"audio"]))
    {
        //[cell setNeedsLayout];
        //[cell layoutIfNeeded];

        AttachmentView * attachmentView = [AttachmentViewFactory viewForAttachment: message.attachment inCell: cell];
        cell.bubble.attachmentView = attachmentView;
    } else {
        cell.bubble.attachmentView = nil;
    }
    if ([message.isOutgoing isEqualToNumber: @YES]) {
        if ([message.deliveries count] > 1) {
            NSLog(@"WARNING: NOT YET IMPLEMENTED: delivery status for multiple deliveries");
        }
        for (Delivery * myDelivery in message.deliveries) {
            if ([myDelivery.state isEqualToString:kDeliveryStateNew] ||
                [myDelivery.state isEqualToString:kDeliveryStateDelivering])
            {
                cell.bubble.state = BubbleStateInTransit;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateDelivered] ||
                       [myDelivery.state isEqualToString:kDeliveryStateConfirmed])
            {
                cell.bubble.state = BubbleStateDelivered;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateFailed]) {
                cell.bubble.state = BubbleStateFailed;
            } else {
                NSLog(@"ERROR: unknow delivery state %@", myDelivery.state);
            }
        }
    }
}

#pragma mark - MessageViewControllerDelegate methods

-(BOOL) messageView:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender {
    // NSLog(@"messageView:canPerformAction:");
    if (action == @selector(deleteMessage:)) return YES;
    if (action == @selector(copy:)) {return YES;}

    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];

    if (action == @selector(copy:)) {return YES;}
#ifdef DEBUG
    if (action == @selector(resendMessage:)) {return YES;}
#endif
    if (action == @selector(forwardMessage:)) {return YES;}
    
    if (action == @selector(saveMessage:)) {
        if ([message.isOutgoing isEqualToNumber: @NO]) {
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

- (void) messageView:(MessageCell *)theCell resendMessage:(id)sender {
    NSLog(@"resendMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    for (int i = 0; i < 10;++i) {
        [self.chatBackend forwardMessage: message.body toContact:message.contact withAttachment:message.attachment];
    }
}

- (void) messageView:(MessageCell *)theCell forwardMessage:(id)sender {
    NSLog(@"forwardMessage");
    self.messageToForward = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    [self.navigationController.sideMenu toggleRightSideMenu];
    // [self.chatBackend forwardMessage: message.body toContact:message.contact withAttachment:message.attachment];
}

- (void) messageView:(MessageCell *)theCell saveMessage:(id)sender {
    // NSLog(@"saveMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    Attachment * attachment = message.attachment;
    
    if ([attachment.mediaType isEqualToString: @"image"]) {
        [attachment loadImageAttachmentImage: ^(UIImage* image, NSError* error) {
            // NSLog(@"saveMessage: loadImageAttachmentImage done");
            if (image) {
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        // NSLog(@"Saved image to Library");
                    } else {
                        NSLog(@"Error saving image in Library, error = %@", error);
                    }
                };
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeImageToSavedPhotosAlbum:[image CGImage]
                                          orientation:(ALAssetOrientation)[image imageOrientation]
                                      completionBlock:completeBlock];
            } else {
                NSLog(@"saveMessage: Failed to get image: %@", error);
            }
        }];
        return;
    }
    if ([attachment.mediaType isEqualToString: @"video"]) {
        NSString * myVideoFilePath = [[NSURL URLWithString: attachment.localURL] path];
        
        if ( UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(myVideoFilePath)) {
            UISaveVideoAtPathToSavedPhotosAlbum(myVideoFilePath, nil, nil, nil);
            // NSLog(@"didPickAttachment: saved video in album at path = %@",myVideoFilePath);
        } else {
            NSLog(@"didPickAttachment: failed to save video in album at path = %@",myVideoFilePath);
        }
    }
}

- (void) messageView:(MessageCell *)theCell copy:(id)sender {
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
            if (theImage != nil) {
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
- (void) messageView:(MessageCell *)theCell deleteMessage:(id)sender {
    // NSLog(@"deleteMessage");
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    
    if (message.attachment != nil) {
        if (message.attachment.ownedURL.length > 0) {
            NSURL * myURL = [NSURL URLWithString:message.attachment.ownedURL];
            if ([myURL isFileURL]) {
                [[NSFileManager defaultManager] removeItemAtURL:myURL error:nil];
            }
            [self.managedObjectContext deleteObject: message.attachment];
        }
    }
    
    for (Delivery * d in message.deliveries) {
        [self.managedObjectContext deleteObject: d];
    }
    
    [self.managedObjectContext deleteObject: message];
}

- (void) presentAttachmentViewForCell: (MessageCell *) theCell {
    HXOMessage * message = [self.fetchedResultsController objectAtIndexPath: [self.tableView indexPathForCell:theCell]];
    // NSLog(@"@presentAttachmentViewForCell attachment = %@", message.attachment);
    
    [self presentViewForAttachment:message.attachment];
}

- (void) presentViewForAttachment:(Attachment *) myAttachment {
    if ([myAttachment.mediaType isEqual: @"video"]) {
        // TODO: lazily allocate _moviePlayerController once
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeNone;
        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"audio"]) {
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeNone;
        
        UIView * myView = [[UIImageView alloc] initWithImage:myAttachment.previewImage];
        
        CGRect myFrame = myView.frame;
        myFrame.size = CGSizeMake(320,320);
        myView.frame = myFrame;
        
        myView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        
        [_moviePlayerViewController.moviePlayer.view addSubview:myView];

        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"image"]) {
        [myAttachment loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"attachment view loadimage done");
            if (theImage != nil) {
                self.imageViewController.image = theImage;
                [self presentViewController: self.imageViewController animated: YES completion: nil];
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
    // NSLog(@"atscrollToBottomAnimated %d", animated);
    if ([self.fetchedResultsController.fetchedObjects count]) {
        NSInteger lastSection = [self numberOfSectionsInTableView: self.tableView] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:  [self tableView: self.tableView numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
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
    // save index path of bottom most visible cell
    NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
    self.partner.rememberedLastVisibleChatCell = [indexPaths lastObject];
}

- (void) scrollToCell:(NSIndexPath*)theCell {
    // save index path of bottom most visible cell
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
    [self.partner removeObserver: self forKeyPath: @"nickName"];
    [self.partner removeObserver: self forKeyPath: @"connectionStatus"];
    [self.partner removeObserver: self forKeyPath: @"avatarImage"];
}

@end
