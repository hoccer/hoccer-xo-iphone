//
//  DetailViewController.m
//  HoccerTalk
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

#import "TalkMessage.h"
#import "Delivery.h"
#import "AppDelegate.h"
#import "AttachmentPickerController.h"
#import "InsetImageView.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "ChatTableCells.h"
#import "iOSVersionChecks.h"
#import "AutoheightLabel.h"
#import "Attachment.h"
#import "AttachmentViewFactory.h"
#import "BubbleView.h"
#import "HTUserDefaults.h"
#import "ImageViewController.h"

@interface ChatViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, nonatomic) UIView* attachmentPreview;
@property (nonatomic,strong) NSIndexPath * firstNewMessage;
@property (nonatomic, readonly) MessageCell* messageCell;
@property (nonatomic, readonly) ChatTableSectionHeaderCell* headerCell;
@property (strong) UIImage* avatarImage;
@property (strong, nonatomic) MPMoviePlayerViewController *  moviePlayerViewController;
@property (readonly, strong, nonatomic) ImageViewController * imageViewController;

- (void)configureCell:(UITableViewCell *)cell forMessage:(TalkMessage *) message;
- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;
@synthesize messageCell = _messageCell;
@synthesize headerCell = _headerCell;
@synthesize moviePlayerViewController = _moviePlayerViewController;
@synthesize imageViewController = _imageViewController;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];

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
    UIMenuItem *mySaveToAlbumMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Save to Album", nil) action:@selector(saveToAlbum:)];
    UIMenuItem *myInContactsMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Save in Contacts", nil) action:@selector(saveInContacts:)];
    UIMenuItem *myForwardMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward", nil) action:@selector(forwardItem:)];
    UIMenuItem *myCopyTextMenuItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy Text", nil) action:@selector(copyText:)];
    //[menuController setMenuItems:[NSArray arrayWithObjects:myMenuItem, nil]];
    [menuController setMenuItems:@[mySaveToAlbumMenuItem,myInContactsMenuItem,myForwardMenuItem,myCopyTextMenuItem]];
    [menuController update];

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

- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }

    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
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
        [self.chatBackend sendMessage: self.textField.text toContact: self.partner withAttachment: self.currentAttachment];
        self.currentAttachment = nil;
        self.textField.text = @"";
    }
    [self removeAttachmentPreview];
}

- (IBAction) addAttachmentPressed:(id)sender {
    [self.textField resignFirstResponder];
    [self.attachmentPicker showInView: self.view];
}

- (IBAction) attachmentPressed: (id)sender {
    [self.textField resignFirstResponder];
    [self showAttachmentOptions];
}

#pragma mark - Attachments

- (AttachmentPickerController*) attachmentPicker {
    if (_attachmentPicker == nil) {
        _attachmentPicker = [[AttachmentPickerController alloc] initWithViewController: self delegate: self];
        
    }
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


- (void) didPickAttachment: (id) attachmentInfo {
    if (attachmentInfo == nil) {
        return;
    }
    [self setSpinningAttachmentButton];
    NSLog(@"didPickAttachment: attachmentInfo = %@",attachmentInfo);

    self.currentAttachment = (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                        inManagedObjectContext: self.managedObjectContext];
    
    if ([attachmentInfo isKindOfClass: [MPMediaItem class]]) {

        // probably an audio item media library
        MPMediaItem * song = (MPMediaItem*)attachmentInfo;
        
        // make a nice and unique filename
        NSString * newFileName = [NSString stringWithFormat:@"%@ - %@.%@",[song valueForProperty:MPMediaItemPropertyArtist],[song valueForProperty:MPMediaItemPropertyTitle],@"m4a" ];
        newFileName = [[self class]sanitizeFileNameString: newFileName];
  
        NSURL * appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
        NSString * myDocDir = [appDocDir path];
        NSString * myUniqueNewFile = [[self class]uniqueFilenameForFilename: newFileName inDirectory: myDocDir];        
        NSString * exportFile = [myDocDir stringByAppendingPathComponent: myUniqueNewFile];
        
        NSLog(@"exportFile = %@", exportFile);
        
        NSURL *assetURL = [song valueForProperty:MPMediaItemPropertyAssetURL];
        NSLog(@"audio assetURL = %@", assetURL);
        
        AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
        
        if ([songAsset hasProtectedContent] == YES) {
            // TODO: user dialog here
            NSLog(@"Media is protected by DRM");
            [self trashCurrentAttachment];
            return;
        }
        
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc]
                                          initWithAsset: songAsset
                                          presetName: AVAssetExportPresetAppleM4A];
        
                
        exporter.outputURL = [NSURL fileURLWithPath:exportFile];
        exporter.outputFileType = AVFileTypeAppleM4A;
        exporter.shouldOptimizeForNetworkUse = YES;
        // exporter.shouldOptimizeForNetworkUse = NO;
        
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            int exportStatus = exporter.status;
            switch (exportStatus) {
                case AVAssetExportSessionStatusFailed: {
                    // log error to text view
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Error_Media_Export_Failed", nil) forKey:NSLocalizedDescriptionKey];
                    NSError *error = [NSError errorWithDomain:@"media export failed" code:796 userInfo:userInfo];
                    NSLog(@"AVAssetExportSessionStatusFailed = %@", error);
                    [self trashCurrentAttachment];
                    break;
                }
                case AVAssetExportSessionStatusCompleted: {
                    NSLog (@"AVAssetExportSessionStatusCompleted");
                    [self.currentAttachment makeAudioAttachment: [assetURL absoluteString] anOtherURL:[exporter.outputURL absoluteString]];
                    [self decorateAttachmentButton: self.currentAttachment.image];

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
                    NSLog (@"AVAssetExportSessionStatusCancelled"); break;}
                case AVAssetExportSessionStatusWaiting: {
                    NSLog (@"AVAssetExportSessionStatusWaiting"); break;}
                default: { NSLog (@"didn't get export status"); break;}
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
                UIImage * image = attachmentInfo[UIImagePickerControllerOriginalImage];
                
                // funky method using ALAssetsLibrary
                ALAssetsLibraryWriteImageCompletionBlock completeBlock = ^(NSURL *assetURL, NSError *error){
                    if (!error) {
                        myURL = assetURL;
                        [self.currentAttachment makeImageAttachment: [myURL absoluteString]
                                                              image: attachmentInfo[UIImagePickerControllerOriginalImage] ];
                        [self decorateAttachmentButton: image];
                    } else {
                        NSLog(@"Error saving image in Library, error = %@", error);
                        [self trashCurrentAttachment];
                    }
                };
                
                if(image) {
                    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                    [library writeImageToSavedPhotosAlbum:[image CGImage]
                                              orientation:(ALAssetOrientation)[image imageOrientation]
                                          completionBlock:completeBlock];
                }
            } else {
                // image from album
                [self.currentAttachment makeImageAttachment: [myURL absoluteString]
                                                      image: attachmentInfo[UIImagePickerControllerOriginalImage] ];
                [self decorateAttachmentButton: attachmentInfo[UIImagePickerControllerOriginalImage]];
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
                    NSLog(@"video myTempURL = %@", myTempURL);
                    self.currentAttachment.ownedURL = [myTempURL copy];
                } else {
                    NSLog(@"didPickAttachment: failed to save video in album at path = %@",tempFilePath);
                    [self trashCurrentAttachment];
                }
            }
            [self.currentAttachment makeVideoAttachment: [myURL2 absoluteString] anOtherURL: nil];
            [self decorateAttachmentButton: self.currentAttachment.image];
            return;
        }
    }
    // Do no do anything here because some functions above will finish asynchronously
    [self trashCurrentAttachment];
}

- (void) decorateAttachmentButton:(UIImage *) theImage {
    if (theImage) {
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
        self.attachmentPreview = nil;
    }
}


- (void) setSpinningAttachmentButton {
    UIActivityIndicatorView * preview = [[UIActivityIndicatorView alloc] init];
    self.attachmentPreview = preview;
    preview.frame = _attachmentButton.frame;
    preview.autoresizingMask = _attachmentButton.autoresizingMask;
    [preview startAnimating];
    [self.chatbar addSubview: preview];
    _attachmentButton.hidden = YES;
}


- (void) trashCurrentAttachment {
    if (self.currentAttachment != nil) {
        [self.managedObjectContext deleteObject: self.currentAttachment];
        self.currentAttachment = nil;
    }
    [self decorateAttachmentButton:nil];
}

- (void) showAttachmentOptions {
    UIActionSheet * sheet = [[UIActionSheet alloc] initWithTitle: NSLocalizedString(@"Attachment", @"Actionsheet Title")
                                                        delegate: self
                                               cancelButtonTitle: NSLocalizedString(@"Cancel", @"Actionsheet Button Title")
                                          destructiveButtonTitle: nil
                                               otherButtonTitles: NSLocalizedString(@"Remove Attachment", @"Actionsheet Button Title")/*,
                                                                  NSLocalizedString(@"View Attachment", @"Actionsheet Button Title")*/,
                                                                  nil];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    [sheet showInView: self.view];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    switch (buttonIndex) {
        case 0:
            [self removeAttachmentPreview];
            break;
        case 1:
            NSLog(@"Viewing attachments not yet implemented");
            break;
        default:
            break;
    }
}

- (void) removeAttachmentPreview {
    if (self.attachmentPreview != nil) {
        [self.attachmentPreview removeFromSuperview];
        self.attachmentPreview = nil;
        self.attachmentButton.hidden = NO;
    }
    [self trashCurrentAttachment];
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

- (ChatTableSectionHeaderCell*) headerCell {
    if (_headerCell == nil) {
        _headerCell = [self.tableView dequeueReusableCellWithIdentifier: [ChatTableSectionHeaderCell reuseIdentifier]];
    }
    return _headerCell;
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
    TalkMessage * message = (TalkMessage*)[self.fetchedResultsController objectAtIndexPath:indexPath];

    NSString * identifier = [message.isOutgoing isEqualToNumber: @YES] ? [RightMessageCell reuseIdentifier] : [LeftMessageCell reuseIdentifier];
    MessageCell *cell = [tableView dequeueReusableCellWithIdentifier: identifier forIndexPath:indexPath];

    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    cell.indexPath = indexPath;
    cell.delegate = self;
    [self configureCell: cell forMessage: message];

    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    ChatTableSectionHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier: [ChatTableSectionHeaderCell reuseIdentifier]];
    cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    cell.label.text = sectionInfo.name;
    cell.label.shadowColor  = [UIColor whiteColor];
    cell.label.shadowOffset = CGSizeMake(0.0, 1.0);
    cell.backgroundImage.image = [UIImage imageNamed: @"date_cell_bg"];
    return cell.contentView;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo name];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // XXX the -1 avoids a view glitch. A light gray line appears without it. I think that is
    //     because the table view assuemes there is a 1px separator. However, sometimes the
    //     grey line still appears ...
    return self.headerCell.contentView.bounds.size.height;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
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

    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];

    CGRect frame = self.messageCell.frame;
    self.messageCell.frame = CGRectMake(frame.origin.x, frame.origin.y, width, frame.size.height);

    return [self.messageCell heightForMessage: message];
}

#pragma mark - Table view menu delegate


- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

-(BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return (action == @selector(copy:));
}

- (BOOL)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return YES;
}


#pragma mark - Core Data Stack

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectContext != nil) {
        return _managedObjectModel;
    }

    _managedObjectModel = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectModel;
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

        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending: YES];
        NSArray *sortDescriptors = @[sortDescriptor];

        [fetchRequest setSortDescriptors:sortDescriptors];

        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath: @"timeSection" cacheName: [NSString stringWithFormat: @"Messages-%@", partner.objectID]];
        _fetchedResultsController.delegate = self;

        resultsControllers[partner.objectID] = _fetchedResultsController;

        NSError *error = nil;
        if (![_fetchedResultsController performFetch:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    } else {
        _fetchedResultsController.delegate = self;
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }

    self.firstNewMessage = nil;
    [self.tableView reloadData];
    [self scrollToBottom: NO];
    [self configureView];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString: @"nickName"] ||
        [keyPath isEqualToString: @"connectionStatus"]) {
        // self.title = [object nickName];
        self.title = [object nickNameWithStatus];
    } else if ([keyPath isEqualToString: @"avatarImage"]) {
        NSLog(@"======== new avatar =============");
        NSArray * indexPaths = [self.tableView indexPathsForVisibleRows];
        [self.tableView beginUpdates];
        for (int i = 0; i < indexPaths.count; ++i) {
            NSIndexPath * indexPath = indexPaths[i];
            TalkMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] forMessage: message];
        }
        [self.tableView endUpdates];
    }
}

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
            if (self.firstNewMessage == nil) {
                self.firstNewMessage = newIndexPath;
            }
            break;
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
        {
            TalkMessage * message = [self.fetchedResultsController objectAtIndexPath:indexPath];
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
    if (self.firstNewMessage != nil) {
        [self.tableView scrollToRowAtIndexPath: self.firstNewMessage atScrollPosition: UITableViewScrollPositionBottom animated: YES];
        self.firstNewMessage = nil;
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    [self setNavigationBarBackgroundWithLines];

    [self scrollToBottom: NO];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self trashCurrentAttachment];
}

- (void)configureCell:(MessageCell *)cell forMessage:(TalkMessage *) message {

    if (self.avatarImage == nil) {
        NSData * myImageData = [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatar];
        if (myImageData != nil) {
            self.avatarImage = [UIImage imageWithData: myImageData];
        } else {
            self.avatarImage = [UIImage imageNamed: @"avatar_default_contact"];
        }
    }

    if ([message.isRead isEqualToNumber: @NO]) {
        message.isRead = @YES;
        [self.managedObjectContext refreshObject: message.contact mergeChanges:YES];
    }

    cell.message.text = message.body;
    UIImage * avatar = [message.isOutgoing isEqualToNumber: @YES] ? self.avatarImage : self.partner.avatarImage;
    avatar = avatar != nil ? avatar : [UIImage imageNamed: @"avatar_default_contact"];

    cell.avatar.image = avatar;

    if (message.attachment &&
        ([message.attachment.mediaType isEqualToString:@"image"] ||
         [message.attachment.mediaType isEqualToString:@"video"] ||
         [message.attachment.mediaType isEqualToString:@"audio"]))
    {
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
            if ([myDelivery.state isEqualToString:kDeliveryStateNew]) {
                cell.bubble.alpha = 0.1;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateDelivering]) {
                cell.bubble.alpha = 0.25;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateDelivered]) {
                cell.bubble.alpha = 0.5;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateConfirmed]) {
                cell.bubble.alpha = 1.0;
            } else if ([myDelivery.state isEqualToString:kDeliveryStateFailed]) {
                cell.backgroundColor = [UIColor redColor];
            } else {
                NSLog(@"ERROR: unknow delivery state %@", myDelivery.state);
            }
        }
    }
}

#pragma mark - MessageViewControllerDelegate methods

-(BOOL) messageView:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender {
    NSLog(@"messageView:canPerformAction:");
    if (action == @selector(saveInContacts:)) return NO;
    if (action == @selector(forwardItem:)) return YES;

    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];

    if (action == @selector(copyText:)) {
        if (message.body.length > 0) {
            return YES;
        }
        return NO;        
    }
    
    if (action == @selector(saveToAlbum:)) {
        Attachment * myAttachment = message.attachment;
        if (myAttachment != nil) {
            if ([myAttachment.mediaType isEqual: @"video"] ||
                [myAttachment.mediaType isEqual: @"image"]) {
                return YES;
            }
        }
        return NO;
    }
    return NO;
}
- (void) messageView:(MessageCell *)theCell saveToAlbum:(id)sender {
    NSLog(@"saveToAlbum");
    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];
}
- (void) messageView:(MessageCell *)theCell forwardItem:(id)sender {
    NSLog(@"forwardItem");
    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];
}

- (void) messageView:(MessageCell *)theCell saveInContacts:(id)sender {
    NSLog(@"saveInContacts");
    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];
}

- (void) messageView:(MessageCell *)theCell copyText:(id)sender {
    NSLog(@"copyText");
    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];
}


- (void) presentAttachmentViewForCell: (MessageCell *) theCell {
    TalkMessage * message = [self.fetchedResultsController objectAtIndexPath: theCell.indexPath];
    // NSLog(@"@presentAttachmentViewForCell attachment = %@", message.attachment);
    
    Attachment * myAttachment = message.attachment;
    if ([myAttachment.mediaType isEqual: @"video"]) {
        // TODO: lazily allocate _moviePlayerController once
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeOne;
        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"audio"]) {
        _moviePlayerViewController = [[MPMoviePlayerViewController alloc] initWithContentURL: [myAttachment contentURL]];
        _moviePlayerViewController.moviePlayer.repeatMode = MPMovieRepeatModeOne;
        
        UIView * myView = [[UIImageView alloc] initWithImage:myAttachment.image];
        
        CGRect myFrame = myView.frame;
        myFrame.size = CGSizeMake(320,320);
        myView.frame = myFrame;
        
        myView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
        
        [_moviePlayerViewController.moviePlayer.view addSubview:myView];

        [self presentMoviePlayerViewControllerAnimated: _moviePlayerViewController];
    } else  if ([myAttachment.mediaType isEqual: @"image"]) {
        self.imageViewController.image = myAttachment.image;
        [self presentViewController: self.imageViewController animated: YES completion: nil];
    }
}

- (ImageViewController*) imageViewController {
    if (_imageViewController == nil) {
        _imageViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ImageViewController"];
    }
    return _imageViewController;
}

- (void) scrollToBottom: (BOOL) animated {
    if ([self.fetchedResultsController.fetchedObjects count]) {
        NSInteger lastSection = [self numberOfSectionsInTableView: self.tableView] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:  [self tableView: self.tableView numberOfRowsInSection: lastSection] - 1 inSection: lastSection];
        [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionBottom animated: animated];
    }
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    // trigger relayout on orientation change. However, there has to be a better way to do this...
    [self.tableView reloadData];
}

- (void) dealloc {
    [self.partner removeObserver: self forKeyPath: @"nickName"];
    [self.partner removeObserver: self forKeyPath: @"connectionStatus"];
    [self.partner removeObserver: self forKeyPath: @"avatarImage"];
}

@end
