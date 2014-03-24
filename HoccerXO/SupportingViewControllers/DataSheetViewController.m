//
//  DataSheetViewController.m
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DataSheetViewController.h"

@interface DataSheetViewController ()

@end

@implementation DataSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void) controllerWillChangeContent: (DataSheetController*) controller {

}

- (void) controller: (DataSheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (int) type newIndexPath: (NSIndexPath*) newIndexPath {

}

- (void) controller: (DataSheetController*) controller didChangeSection: (NSUInteger) sectionIndex {

}

- (void) controllerDidChangeContent: (DataSheetController*) controller {
    
}


@end
