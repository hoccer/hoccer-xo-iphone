//
//  SegmentedViewController.m
//  HoccerXO
//
//  Created by David Siegel on 22.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "SegmentedViewController.h"

@interface SegmentedViewController ()

@property (nonatomic,strong) NSMutableDictionary * cachedViewControllers;
@property (nonatomic,strong) UIViewController    * currentViewController;
@property (nonatomic,assign) BOOL                  inTransition;

@end

@implementation SegmentedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.cachedViewControllers = [NSMutableDictionary dictionary];
    self.inTransition = NO;
    UISegmentedControl * segmentedControl = [[UISegmentedControl alloc] initWithItems: [self localizedSegmentTitles]];
    self.navigationItem.titleView = segmentedControl;
    
    segmentedControl.selectedSegmentIndex = 0;
    
    
    [segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
    UIViewController *vc = [self viewControllerForSegmentIndex: segmentedControl.selectedSegmentIndex];
    [self addChildViewController:vc];
    vc.view.frame = self.view.bounds;
    [self.view addSubview:vc.view];
    self.navigationItem.leftBarButtonItem = vc.navigationItem.leftBarButtonItem;
    self.navigationItem.rightBarButtonItem = vc.navigationItem.rightBarButtonItem;
    self.currentViewController = vc;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    self.cachedViewControllers = [NSMutableDictionary dictionary];
}

- (NSArray*) localizedSegmentTitles {
    NSMutableArray * localizedTitles = [NSMutableArray arrayWithCapacity: self.childViewControllerTitles.count];
    for (NSString* title in self.childViewControllerTitles) {
        [localizedTitles addObject: NSLocalizedString(title, nil)];
    }
    return localizedTitles;
}

- (IBAction)segmentChanged:(UISegmentedControl *)sender {
    if (self.inTransition) {
        return;
    }
    UIViewController *vc = [self viewControllerForSegmentIndex: sender.selectedSegmentIndex];
    [self addChildViewController:vc];
    self.inTransition = YES;
    [self transitionFromViewController: self.currentViewController toViewController:vc duration:0.2 options: UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [self.currentViewController.view removeFromSuperview];
        vc.view.frame = self.view.bounds;
        [self.view addSubview: vc.view];
    } completion:^(BOOL finished) {
        self.navigationItem.leftBarButtonItem = vc.navigationItem.leftBarButtonItem;
        self.navigationItem.rightBarButtonItem = vc.navigationItem.rightBarButtonItem;
        [vc didMoveToParentViewController:self];
        [self.currentViewController willMoveToParentViewController: nil];
        [self.currentViewController removeFromParentViewController];
        self.currentViewController = vc;
        self.inTransition = NO;
        if ([self viewControllerForSegmentIndex: sender.selectedSegmentIndex] != self.currentViewController) {
            [self segmentChanged: sender];
        }
    }];
    self.navigationItem.title = vc.title;
}

- (UIViewController*) viewControllerForSegmentIndex: (NSInteger) index {
    NSString * storyboardId = self.childViewControllerStoryboardIDs[index];
    if ( ! self.cachedViewControllers[storyboardId]) {
        self.cachedViewControllers[storyboardId] = [self.storyboard instantiateViewControllerWithIdentifier: storyboardId];
    }
    return self.cachedViewControllers[storyboardId];
}

@end
