//
//  ContactListViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 22.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@class ConversationViewController;
@class MFSideMenu;
@class HoccerTalkBackend;

@interface ContactQuickListViewController : UIViewController <NSFetchedResultsControllerDelegate,UISearchBarDelegate,UIActionSheetDelegate,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic,strong) IBOutlet UITableView* tableView;
@property (nonatomic,strong) IBOutlet UISearchBar* searchBar;
@property (strong, nonatomic) IBOutlet UIButton *inviteButton;

@property (nonatomic, assign) ConversationViewController * conversationViewController;
@property (nonatomic, assign) MFSideMenu *sideMenu;

@property (nonatomic, readonly) HoccerTalkBackend * chatBackend;

@property (strong, nonatomic, readonly) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
