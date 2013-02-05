//
//  ViewController.m
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ViewController.h"
#import "UIButton+GlossyRounded.h"
#import <QuartzCore/QuartzCore.h>

@interface ViewController ()
{
    IBOutlet UIView *      textInputView;
    IBOutlet UITableView * chatTable;
    IBOutlet UITextField * textField;
    IBOutlet UIButton *    sendButton;
}

- (void) scrollToBottom;

@end


@implementation ViewController

@synthesize chatController;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    [sendButton makeRoundAndGlossy];
    
    textField.layer.cornerRadius = 17;
    textField.clipsToBounds = YES;
    
    self.chatController = [[ChatController alloc] init];
    
    // XXX
    chatTable.dataSource = chatController;
    chatTable.delegate = chatController;
    chatController.tableView = chatTable;


    if (chatController.messageCount > 0) {
        [chatTable setContentOffset:CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) scrollToBottom {
    if (chatController.messageCount > 0) {
        NSIndexPath* ipath = [NSIndexPath indexPathForRow: chatController.messageCount - 1 inSection: 0];
        [chatTable scrollToRowAtIndexPath: ipath atScrollPosition: UITableViewScrollPositionTop animated: YES];
    }
}

#pragma mark - Keyboard events

- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.2f animations:^{
        
        CGRect frame = textInputView.frame;
        frame.origin.y -= kbSize.height;
        textInputView.frame = frame;
        
        frame = chatTable.frame;
        frame.size.height -= kbSize.height;
        chatTable.frame = frame;
    }];
    [self scrollToBottom];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView animateWithDuration:0.2f animations:^{
        
        CGRect frame = textInputView.frame;
        frame.origin.y += kbSize.height;
        textInputView.frame = frame;
        
        frame = chatTable.frame;
        frame.size.height += kbSize.height;
        chatTable.frame = frame;
    }];
}

#pragma mark - Actions

- (IBAction)sendPressed:(id)sender
{
    [textField resignFirstResponder];
    if (textField.text.length > 0) {
        [chatController addMessage: textField.text];
        textField.text = @"";
        [self scrollToBottom];
    }
}

@end
