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
@class AttachmentButton;

@interface ChatViewController : UIViewController
<
UISplitViewControllerDelegate, AttachmentPickerControllerDelegate, UIActionSheetDelegate,
UITextViewDelegate, NSFetchedResultsControllerDelegate, MessageViewControllerDelegate,
ABUnknownPersonViewControllerDelegate, HXOHyperLabelDelegate, TransferProgressIndication,
UIDocumentInteractionControllerDelegate
>
{
    NSMutableDictionary        *resultsControllers;
}

@property (nonatomic, strong) IBOutlet UIToolbar              * chatbar;
@property (nonatomic, strong) IBOutlet UITableView            * tableView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint     * keyboardHeight;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint     * chatbarHeight;
@property (nonatomic, strong) UITextView                      * messageField;
@property (nonatomic, strong) AttachmentButton                * attachmentButton;
@property (nonatomic, strong) UIButton                        * sendButton;

@property (nonatomic, strong) Contact                         * partner;
@property (nonatomic, strong) Contact                         * inspectedObject;
@property (nonatomic, strong) HXOBackend                      * chatBackend;
@property (nonatomic, strong) NSFetchedResultsController      * fetchedResultsController;

@property (nonatomic, strong) NSManagedObjectModel            * managedObjectModel;
@property (nonatomic, strong) Attachment                      * currentAttachment;
@property (nonatomic, strong) AVAssetExportSession            * currentExportSession;
@property (nonatomic, strong) id                                currentPickInfo;

@property (nonatomic, strong) id                                connectionInfoObserver;

@property (nonatomic, strong) UIDocumentInteractionController * interactionController;

- (void) setPartner: (Contact*) partner;
- (void) scrollToBottomAnimated: (BOOL) animated;
- (IBAction)sendPressed:(id)sender;

- (void) actionButtonPressed: (id) sender;

- (void) decorateAttachmentButton:(UIImage *) theImage;
- (void) trashCurrentAttachment;

@end
