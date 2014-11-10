//
//  AudioAttachmentListViewController.h
//  HoccerXO
//
//  Created by Guido Lorenz on 25.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTableViewController.h"
#import "AddToCollectionListViewControllerDelegate.h"
#import "AudioAttachmentDataSourceDelegate.h"
#import "AttachmentPresenterDelegate.h"

@class Collection;
@class Contact;

@interface AudioAttachmentListViewController : HXOTableViewController <AudioAttachmentDataSourceDelegate, AddToCollectionListViewControllerDelegate, UIActionSheetDelegate, UISearchBarDelegate, UISearchDisplayDelegate, AttachmentPresenterDelegate>

- (void)wasSelectedByTabBarController:(UITabBarController *)tabBarController;

@property (nonatomic, strong) Collection *collection;
@property (nonatomic, strong) Contact *contact;

@property (nonatomic, strong) UIButton *addToCollectionButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *sendButton;

@property (nonatomic,strong) UISegmentedControl * mediaTypeControl;

@end
