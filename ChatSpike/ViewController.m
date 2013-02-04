//
//  ViewController.m
//  ChatSpike
//
//  Created by David Siegel on 04.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    IBOutlet UIView *textInputView;
    IBOutlet UITableView * chatTable;
    IBOutlet UITextField * textField;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Keyboard events

- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSLog(@"keyboardWasShown");
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
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSLog(@"keyboardWillBeShown");
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
    textField.text = @"";
    [textField resignFirstResponder];
}

@end
