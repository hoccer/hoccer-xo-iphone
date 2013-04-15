//
//  ContactListViewController.h
//  HoccerTalk
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import <MessageUI/MessageUI.h>

#import "TableViewControllerWithPlaceholder.h"

@interface ContactListViewController : TableViewControllerWithPlaceholder <NSFetchedResultsControllerDelegate,UIActionSheetDelegate,MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate, UISearchBarDelegate>

@property (nonatomic,strong) IBOutlet UISearchBar* searchBar;

@end
