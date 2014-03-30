//
//  DetailViewController.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Contact.h"
#import "AttachmentPickerController.h"
#import "MessageCell.h"
#import "HXOHyperLabel.h"
#import "Attachment.h"

@class HXOBackend;
@class AVAssetExportSession;
@class ChatBar;

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate, AttachmentPickerControllerDelegate, UIActionSheetDelegate, UITextViewDelegate, NSFetchedResultsControllerDelegate, MessageViewControllerDelegate, ABUnknownPersonViewControllerDelegate, HXOHyperLabelDelegate, TransferProgressIndication, UIDocumentInteractionControllerDelegate>
{
    NSMutableDictionary        *resultsControllers;
}

@property (strong, nonatomic)   Contact *                      partner;
@property (strong, nonatomic)   Contact *                      inspectedObject;
@property (readonly, nonatomic) HXOBackend *  chatBackend;
@property (strong, nonatomic)   IBOutlet UIToolbar * chatbar;
@property (strong, nonatomic)   UITextView *  messageField;
@property (strong, nonatomic)   UIControl *   attachmentButton;
@property (strong, nonatomic) IBOutlet UITableView *         tableView;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint * keyboardHeight;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint * chatbarHeight;

@property (strong, nonatomic) NSFetchedResultsController *   fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *       managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *         managedObjectModel;

@property (strong, nonatomic) Attachment * currentAttachment;
@property (strong, nonatomic) AVAssetExportSession * currentExportSession;
@property (strong, nonatomic) id currentPickInfo;

@property (strong, nonatomic) id connectionInfoObserver;

@property (strong, nonatomic) UIDocumentInteractionController *interactionController;

// @property UIInterfaceOrientation interfaceOrientation;

- (void) setPartner: (Contact*) partner;
- (void) scrollToBottomAnimated: (BOOL) animated;
- (IBAction)sendPressed:(id)sender;
- (IBAction) addAttachmentPressed:(id)sender;
- (void) decorateAttachmentButton:(UIImage *) theImage;
- (void) trashCurrentAttachment;

@end
