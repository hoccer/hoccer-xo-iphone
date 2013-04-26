//
//  ImageViewController.m
//  HoccerXO
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageViewController.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat kImageViewerOversize = 1.03;

@interface ImageViewController ()

@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem * doneButton;

@end

@implementation ImageViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    self.navigationBar.translucent = YES;
    [self.navigationBar setBackgroundImage: nil forBarMetrics: UIBarMetricsDefault];

    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewDoubleTapped:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.scrollView addGestureRecognizer:doubleTapRecognizer];

    UITapGestureRecognizer *twoFingerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTwoFingerTapped:)];
    twoFingerTapRecognizer.numberOfTapsRequired = 1;
    twoFingerTapRecognizer.numberOfTouchesRequired = 2;
    [self.scrollView addGestureRecognizer:twoFingerTapRecognizer];
    
    self.scrollView.alwaysBounceHorizontal = YES;
    self.scrollView.alwaysBounceVertical   = YES;
    self.view.backgroundColor = [UIColor colorWithPatternImage: [UIImage imageNamed: @"bg-noise"]];

    /*
    self.imageView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.imageView.layer.shadowOpacity = 0.8;
    self.imageView.layer.shadowRadius  = 10;
    self.imageView.layer.shadowOffset = CGSizeMake(0, 0);
     */

    [self.doneButton setBackgroundImage: [UIImage imageNamed: @"navbar-btn-blue"] forState: UIControlStateNormal barMetrics:UIBarMetricsDefault];
}

- (void) viewWillAppear:(BOOL)animated {

    [super viewWillAppear: animated];

    self.imageView.image = self.image;

    [self updateZoomScale];

}

- (void)updateZoomScale {
    // reset the zoom to one - avoids problems with interface orientation changes
    // and frame changes when updating the picture
    self.scrollView.zoomScale = 1.0;

    self.imageView.frame = CGRectMake(0.0f, 0.0f, self.image.size.width, self.image.size.height);

    self.scrollView.contentSize = CGSizeMake(self.image.size.width * kImageViewerOversize, self.image.size.height * kImageViewerOversize);

    CGRect scrollViewFrame = self.scrollView.frame;
    CGFloat scaleWidth = scrollViewFrame.size.width / self.scrollView.contentSize.width;
    CGFloat scaleHeight = scrollViewFrame.size.height / self.scrollView.contentSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight) / kImageViewerOversize;
    self.scrollView.minimumZoomScale = minScale;

    self.scrollView.maximumZoomScale = 1.0f;
    self.scrollView.zoomScale = minScale;

    [self centerScrollViewContents];
}

- (void)centerScrollViewContents {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect contentsFrame = self.imageView.frame;

    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    } else {
        contentsFrame.origin.x = 0.0f;
    }

    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    } else {
        contentsFrame.origin.y = 0.0f;
    }

    self.imageView.frame = contentsFrame;
}

- (void)scrollViewDoubleTapped:(UITapGestureRecognizer*)recognizer {
    CGPoint pointInView = [recognizer locationInView:self.imageView];

    CGFloat newZoomScale = self.scrollView.zoomScale * 1.5f;
    newZoomScale = MIN(newZoomScale, self.scrollView.maximumZoomScale);

    CGSize scrollViewSize = self.scrollView.bounds.size;

    CGFloat w = scrollViewSize.width / newZoomScale;
    CGFloat h = scrollViewSize.height / newZoomScale;
    CGFloat x = pointInView.x - (w / 2.0f);
    CGFloat y = pointInView.y - (h / 2.0f);

    CGRect rectToZoomTo = CGRectMake(x, y, w, h);

    [self.scrollView zoomToRect:rectToZoomTo animated:YES];
}

- (void)scrollViewTwoFingerTapped:(UITapGestureRecognizer*)recognizer {
    // Zoom out slightly, capping at the minimum zoom scale specified by the scroll view
    CGFloat newZoomScale = self.scrollView.zoomScale / 1.5f;
    newZoomScale = MAX(newZoomScale, self.scrollView.minimumZoomScale);
    [self.scrollView setZoomScale:newZoomScale animated:YES];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // The scroll view has zoomed, so you need to re-center the contents
    [self centerScrollViewContents];
}

- (IBAction)donePressed:(id)sender {
    [self dismissViewControllerAnimated: YES completion: nil];
}

-(void)didRotateFromInterfaceOrientation: (UIInterfaceOrientation)toInterfaceOrientation {
    // NSLog(@"didRotate");
    [self updateZoomScale];
}

- (void) setImage:(UIImage *)image {
    _image = image;
    // view might not be fully realized yet
    if (self.imageView != nil) {
        self.imageView.image = self.image;
        [self updateZoomScale];
    }
}

- (void)viewDidUnload {
    [self setScrollView:nil];
    [self setImageView:nil];
    [self setNavigationBar:nil];
    [super viewDidUnload];
}
@end
