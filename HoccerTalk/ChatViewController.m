//
//  DetailViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "UIButton+GlossyRounded.h"
#import "Message.h"
#import "AppDelegate.h"
#import "AttachmentPickerController.h"
#import "InsetImageView.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"

@interface ChatViewController ()

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, readonly) AttachmentPickerController* attachmentPicker;
@property (strong, nonatomic) UIView* attachmentPreview;

- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;
@synthesize attachmentPicker = _attachmentPicker;

#pragma mark - Managing the detail item

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = [self hoccerTalkContactsButton];


    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    chatTableController = (ChatTableViewController*)self.childViewControllers[0];

    UIColor * barBackground = [UIColor colorWithPatternImage: [UIImage imageNamed: @"chatbar_bg_noise"]];
    _chatbar.backgroundColor = barBackground;
    UIImageView * backgroundGradient = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"chatbar_bg_gradient"] resizableImageWithCapInsets:UIEdgeInsetsMake(2, 0, 0, 0) resizingMode: UIImageResizingModeStretch]];
    backgroundGradient.frame = _chatbar.bounds;
    [_chatbar addSubview: backgroundGradient];
    backgroundGradient.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;


    [chatTableController setPartner: _partner];

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

    self.chatTableContainer.backgroundColor = [UIColor colorWithPatternImage: [self radialGradient]];

    [self configureView];
}

- (void) awakeFromNib {
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPartner:(Contact*) newPartner {
    if (_partner != newPartner) {
        _partner = newPartner;

        [chatTableController setPartner: newPartner];
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.partner) {
        self.title = self.partner.nickName;
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    _managedObjectContext = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    return _managedObjectContext;
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

    UIScrollView * scrollView = (UIScrollView*)self.chatTableContainer.subviews[0];
    CGPoint contentOffset = scrollView.contentOffset;
    contentOffset.y += keyboardHeight;

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.view.frame;
        frame.size.height -= keyboardHeight;
        self.view.frame = frame;
        scrollView.contentOffset = contentOffset;
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
        [self.chatBackend sendMessage: self.textField.text toContact: self.partner];
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
    if (attachmentInfo[@"UIImagePickerControllerOriginalImage"]) {
        InsetImageView* preview = [[InsetImageView alloc] init];
        self.attachmentPreview = preview;
        preview.frame = _attachmentButton.frame;
        preview.image = attachmentInfo[@"UIImagePickerControllerOriginalImage"];
        preview.borderColor = [UIColor blackColor];
        preview.insetColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];
        preview.autoresizingMask = _attachmentButton.autoresizingMask;
        [preview addTarget: self action: @selector(attachmentPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.chatbar addSubview: preview];
        _attachmentButton.hidden = YES;
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
    CGSize size = self.chatTableContainer.frame.size
    ;
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

@end
