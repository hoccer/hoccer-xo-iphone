//
//  DetailViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"
#import "ChatTableViewController.h"
#import "AttachmentPickerController.h"
#import "GrowingTextView.h"

@class HoccerTalkBackend;

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate,AttachmentPickerControllerDelegate,UIActionSheetDelegate,GrowingTextViewDelegate,UITextViewDelegate>
{
    ChatTableViewController * chatTableController;
}

@property (strong, nonatomic) Contact* partner;
@property (readonly, strong, nonatomic) NSManagedObjectContext * managedObjectContext;
@property (readonly, strong, nonatomic) HoccerTalkBackend *            chatBackend;

@property (strong, nonatomic) Attachment * currentAttachment;


@property (strong, nonatomic) IBOutlet GrowingTextView * textField;
@property (strong, nonatomic) IBOutlet UIButton *        sendButton;
@property (strong, nonatomic) IBOutlet UIView *          chatbar;
@property (strong, nonatomic) IBOutlet UIView *          chatTableContainer;
@property (strong, nonatomic) IBOutlet UITableView *     chatTable;
@property (strong, nonatomic) IBOutlet UIButton *        attachmentButton;

- (IBAction)sendPressed:(id)sender;
- (IBAction) addAttachmentPressed:(id)sender;

@end
