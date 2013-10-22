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
#import "GrowingTextView.h"
#import "ChatTableCells.h"
#import "HXOActionSheet.h"
#import "HXOLinkyLabel.h"

@class HXOBackend;
@class AVAssetExportSession;

@interface ChatViewController : UIViewController <UISplitViewControllerDelegate,AttachmentPickerControllerDelegate,ActionSheetDelegate,GrowingTextViewDelegate,UITextViewDelegate,NSFetchedResultsControllerDelegate, MessageViewControllerDelegate, ABUnknownPersonViewControllerDelegate, HXOLinkyLabelDelegate>
{
    NSMutableDictionary        *resultsControllers;
}

@property (strong, nonatomic) Contact *                      partner;
@property (readonly, strong, nonatomic) HXOBackend *  chatBackend;
@property (strong, nonatomic) IBOutlet GrowingTextView *     textField;
@property (strong, nonatomic) IBOutlet UIButton *            sendButton;
@property (strong, nonatomic) IBOutlet UIView *              chatbar;
@property (strong, nonatomic) IBOutlet UIButton *            attachmentButton;
@property (strong, nonatomic) IBOutlet UIButton *            cancelButton;
@property (strong, nonatomic) IBOutlet UITableView *         tableView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView * attachmentSpinner;
@property (strong, nonatomic) IBOutlet UIView *chatViewResizer;

@property (strong, nonatomic) NSFetchedResultsController *   fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *       managedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *         managedObjectModel;

@property (strong, nonatomic) Attachment * currentAttachment;
@property (strong, nonatomic) AVAssetExportSession * currentExportSession;
@property (strong, nonatomic) id currentPickInfo;

@property (strong, nonatomic) id connectionInfoObserver;

// @property UIInterfaceOrientation interfaceOrientation;

- (void) setPartner: (Contact*) partner;
- (void) scrollToBottomAnimated: (BOOL) animated;
- (IBAction)sendPressed:(id)sender;
- (IBAction) addAttachmentPressed:(id)sender;
- (void) decorateAttachmentButton:(UIImage *) theImage;
- (void) trashCurrentAttachment;

// TODO: move to some utility functions file:
+ (NSString *)uniqueFilenameForFilename: (NSString *)theFilename inDirectory: (NSString *)directory;
+ (NSString *)sanitizeFileNameString:(NSString *)fileName;
+ (NSURL *)uniqueNewFileURLForFileLike:(NSString *)fileNameHint;

@end
