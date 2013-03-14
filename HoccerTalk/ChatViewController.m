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

@interface ChatViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;

#pragma mark - Managing the detail item

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    chatTableController = (ChatTableViewController*)self.childViewControllers[0];

    UIColor * barBackground = [UIColor colorWithPatternImage: [UIImage imageNamed: @"chatbar_bg"]];
    self.chatbar.backgroundColor = barBackground;
    self.attachmentBar.backgroundColor = barBackground;
    [self setAttachmentBarVisibility: NO animated: NO];

    [chatTableController setPartner: _partner];

    UIImage *textfieldBackground = [[UIImage imageNamed:@"chatbar_input-text"] stretchableImageWithLeftCapWidth:12 topCapHeight:12];
    [self.textField setBackground: textfieldBackground];
    self.textField.backgroundColor = [UIColor clearColor];
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 20)];
    self.textField.leftView = paddingView;
    self.textField.leftViewMode = UITextFieldViewModeAlways;

    UIImage *sendButtonBackground = [[UIImage imageNamed:@"chatbar_btn-send"] stretchableImageWithLeftCapWidth:5 topCapHeight:13];
    [self.sendButton setBackgroundImage: sendButtonBackground forState: UIControlStateNormal];
    [self.sendButton setBackgroundColor: [UIColor clearColor]];
    self.sendButton.titleLabel.shadowOffset  = CGSizeMake(0.0, -1.0);
    [self.sendButton setTitleShadowColor:[UIColor colorWithWhite: 0 alpha: 0.4] forState:UIControlStateNormal];

    self.chatTableContainer.backgroundColor = [UIColor colorWithPatternImage: [self radialGradient]];

    [self configureView];

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

- (ChatBackend*) chatBackend {
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
    if (self.textField.text.length > 0) {
        [self.chatBackend sendMessage: self.textField.text toContact: self.partner];
        self.textField.text = @"";
    }
}

- (IBAction) addAttachmentPressed:(id)sender {
    [sender setSelected: ! [sender isSelected]];
    [self setAttachmentBarVisibility: [sender isSelected] animated: YES];
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

    CGContextRestoreGState(cx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    return image;
}

#pragma mark - Attachments

- (void) setAttachmentBarVisibility: (BOOL) visible animated: (BOOL) animated {
    CGRect barFrame = self.attachmentBar.frame;
    CGRect tableFrame = self.chatTableContainer.frame;
    CGFloat height = barFrame.size.height;
    UIScrollView * scrollView = (UIScrollView*)self.chatTableContainer.subviews[0];
    CGPoint contentOffset = scrollView.contentOffset;
    if (visible) {
        barFrame = CGRectMake(barFrame.origin.x, barFrame.origin.y - height, barFrame.size.width, height);
        tableFrame = CGRectMake(tableFrame.origin.x, tableFrame.origin.y, tableFrame.size.width, tableFrame.size.height - height);
        contentOffset.y += height;
    } else {
        barFrame = CGRectMake(barFrame.origin.x, barFrame.origin.y + height, barFrame.size.width, height);
        tableFrame = CGRectMake(tableFrame.origin.x, tableFrame.origin.y, tableFrame.size.width, tableFrame.size.height + height);
        contentOffset.y -= height;
    }

    void (^adjustFrames)() = ^() {
        self.attachmentBar.frame = barFrame;
        self.chatTableContainer.frame = tableFrame;
        scrollView.contentOffset = contentOffset;
    };

    if (animated) {
        [UIView animateWithDuration: 0.2 animations: adjustFrames];
    } else {
        adjustFrames();
    }
}

- (void)viewDidUnload {
    [self setAttachmentBar:nil];
    [self setAttachmentButton:nil];
    [super viewDidUnload];
}
@end
