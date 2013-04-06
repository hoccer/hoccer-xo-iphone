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

#import "TalkMessage.h"
#import "AppDelegate.h"
#import "AttachmentPickerController.h"
#import "InsetImageView.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "LeftMessageCell.h"
#import "RightMessageCell.h"
#import "SectionHeaderCell.h"
#import "iOSVersionChecks.h"
#import "AutoheightLabel.h"
#import "Attachment.h"
#import "AttachmentViewFactory.h"
#import "BubbleView.h"
#import "HTUserDefaults.h"

@interface ChatViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, nonatomic) UIView* attachmentPreview;
@property (nonatomic,strong) NSIndexPath * firstNewMessage;
@property (nonatomic, readonly) MessageCell* messageCell;
@property (nonatomic, readonly) SectionHeaderCell* headerCell;
@property (strong) UIImage* avatarImage;

- (void)configureCell:(UITableViewCell *)cell forMessage:(TalkMessage *) message;
- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;
@synthesize messageCell = _messageCell;
@synthesize headerCell = _headerCell;

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
        self.title = self.partner.nickName;
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

- (void) didPickAttachment: (id) attachmentInfo {
    if (attachmentInfo == nil) {
        return;
    }
    NSLog(@"didPickAttachment: attachmentInfo = %@",attachmentInfo);

    NSString * mediaType = attachmentInfo[UIImagePickerControllerMediaType];

    self.currentAttachment = (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName]
                                                                    inManagedObjectContext: self.managedObjectContext];
    
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
    // Do no do anything here because some functions above will finish asynchronously
    [self trashCurrentAttachment];
}

- (void) decorateAttachmentButton:(UIImage *) theImage {
    if (theImage) {
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
    }
}

- (void) trashCurrentAttachment {
    if (self.currentAttachment != nil) {
        [self.managedObjectContext deleteObject: self.currentAttachment];
        self.currentAttachment = nil;
    }
   
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

- (SectionHeaderCell*) headerCell {
    if (_headerCell == nil) {
        _headerCell = [self.tableView dequeueReusableCellWithIdentifier: [SectionHeaderCell reuseIdentifier]];
    }
    return _headerCell;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
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
    MessageCell *cell = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0") ?
    [tableView dequeueReusableCellWithIdentifier: identifier forIndexPath:indexPath] :
    [tableView dequeueReusableCellWithIdentifier: identifier];


    // Hack to get the look of a plain (non grouped) table with non-floating headers without using private APIs
    // http://corecocoa.wordpress.com/2011/09/17/how-to-disable-floating-header-in-uitableview/
    // ... for now just use the private API
    // cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];

    [self configureCell: cell forMessage: message];

    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SectionHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier: [SectionHeaderCell reuseIdentifier]];
    cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    cell.label.text = sectionInfo.name;
    cell.label.shadowColor  = [UIColor whiteColor];
    cell.label.shadowOffset = CGSizeMake(0.0, 1.0);
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo name];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // XXX the -1 avoids a view glitch. A light gray line appears without it. I think that is
    //     because the table view assuemes there is a 1px separator. However, sometimes the
    //     grey line still appears ...
    return self.headerCell.frame.size.height - 1;
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
    if (partner == nil) {
        return;
    }
    if (_partner == partner) {
        return;
    }
    _partner = partner;

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
    [self scrollToBottom: NO];
}

- (void) viewWillDisappear:(BOOL)animated {
    [self trashCurrentAttachment];
}

- (void)configureCell:(MessageCell *)cell forMessage:(TalkMessage *) message {

    if (self.avatarImage == nil) {
        self.avatarImage = [UIImage imageWithData: [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarImage]];
    }

    if ([message.isRead isEqualToNumber: @NO]) {
        message.isRead = @YES;
        [self.managedObjectContext refreshObject: message.contact mergeChanges:YES];
    }

    cell.message.text = message.body;
    cell.avatar.image = [message.isOutgoing isEqualToNumber: @YES] ? self.avatarImage : message.contact.avatarImage;

    if (message.attachment &&
        ([message.attachment.mediaType isEqualToString:@"image"] ||
         [message.attachment.mediaType isEqualToString:@"video"]))
    {
        UIView * attachmentView = [AttachmentViewFactory viewForAttachment: message.attachment];
        cell.bubble.attachmentView = attachmentView;
    } else {
        cell.bubble.attachmentView = nil;
    }
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

@end
