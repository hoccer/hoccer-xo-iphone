//
//  DetailViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"
#import "AttachmentPickerController.h"
#import "GrowingTextView.h"
#import "ChatTableCells.h"

@class HoccerTalkBackend;


@interface ChatViewController : UIViewController <UISplitViewControllerDelegate,AttachmentPickerControllerDelegate,UIActionSheetDelegate,GrowingTextViewDelegate,UITextViewDelegate,NSFetchedResultsControllerDelegate, MessageViewControllerDelegate>
{
    NSMutableDictionary        *resultsControllers;
}

@property (strong, nonatomic) Contact *                      partner;
@property (readonly, strong, nonatomic) HoccerTalkBackend *  chatBackend;
@property (strong, nonatomic) IBOutlet GrowingTextView *     textField;
@property (strong, nonatomic) IBOutlet UIButton *            sendButton;
@property (strong, nonatomic) IBOutlet UIView *              chatbar;
@property (strong, nonatomic) IBOutlet UIButton *            attachmentButton;
@property (strong, nonatomic) IBOutlet UITableView *         tableView;
@property (strong, nonatomic) UIActivityIndicatorView *      spinner;

@property (strong, nonatomic) NSFetchedResultsController *   fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *       managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *         managedObjectModel;

@property (strong, nonatomic) Attachment * currentAttachment;


- (void) setPartner: (Contact*) partner;
- (void) scrollToBottom: (BOOL) animated;
- (IBAction)sendPressed:(id)sender;
- (IBAction) addAttachmentPressed:(id)sender;
- (void) decorateAttachmentButton:(UIImage *) theImage;
- (void) trashCurrentAttachment;

// MessageViewControllerDelegate methods

- (void) presentAttachmentViewForCell: (MessageCell *) theCell;
- (BOOL) messageView:(MessageCell *)theCell canPerformAction:(SEL)action withSender:(id)sender;


@end
