//
//  ImageViewController.m
//  HoccerXO
//
//  Created by David Siegel on 09.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ImageViewController.h"

#import <QuartzCore/QuartzCore.h>

@interface ImageViewController ()

@property (readonly, nonatomic) UIScrollView * scrollView;
@property (strong, nonatomic)   UIImageView  * imageView;

@end

@implementation ImageViewController

- (void) loadView {
    // giving the view an initial frame avoids CG singular matrix errors
    self.view = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 23, 23)];
}

- (UIScrollView*) scrollView {
    return (UIScrollView*) self.view;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    self.scrollView.delegate = self;
    self.scrollView.backgroundColor = [UIColor blackColor];

    self.imageView = [[UIImageView alloc] initWithImage: nil];
    [self.scrollView addSubview: self.imageView];

    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewDoubleTapped:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.scrollView addGestureRecognizer:doubleTapRecognizer];

    UITapGestureRecognizer *twoFingerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTwoFingerTapped:)];
    twoFingerTapRecognizer.numberOfTapsRequired = 1;
    twoFingerTapRecognizer.numberOfTouchesRequired = 2;
    [self.scrollView addGestureRecognizer:twoFingerTapRecognizer];

    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTapped:)];
    singleTapRecognizer.numberOfTapsRequired = 1;
    singleTapRecognizer.numberOfTouchesRequired = 1;
    [singleTapRecognizer requireGestureRecognizerToFail: doubleTapRecognizer];
    [self.scrollView addGestureRecognizer:singleTapRecognizer];

    self.scrollView.alwaysBounceHorizontal = YES;
    self.scrollView.alwaysBounceVertical   = YES;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];

    [self.navigationController setNavigationBarHidden: YES animated: YES];

    if (self.image) {
        [self updateZoomScale];
    }
}

- (void)updateZoomScale {
    // reset the zoom to one - avoids problems with interface orientation changes
    // and frame changes when updating the picture
    self.scrollView.zoomScale = 1;

    self.scrollView.contentSize = CGSizeMake(_image.size.width, _image.size.height);

    self.imageView.frame = CGRectMake(0, 0, _image.size.width, _image.size.height);
    self.imageView.image = _image;


    CGRect scrollViewFrame = self.scrollView.frame;
    CGFloat scaleWidth = scrollViewFrame.size.width / self.scrollView.contentSize.width;
    CGFloat scaleHeight = scrollViewFrame.size.height / self.scrollView.contentSize.height;
    CGFloat minScale = MIN(MIN(scaleWidth, scaleHeight),1);
    self.scrollView.minimumZoomScale = minScale;

    self.scrollView.maximumZoomScale = 1.5;
    self.scrollView.zoomScale = minScale;

    [self centerScrollViewContents];
}

- (void)centerScrollViewContents {
    CGSize boundsSize = self.scrollView.bounds.size;
    CGRect contentsFrame = self.imageView.frame;

    if (contentsFrame.size.width < boundsSize.width) {
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2;
    } else {
        contentsFrame.origin.x = 0.0f;
    }

    if (contentsFrame.size.height < boundsSize.height) {
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2;
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

- (void)scrollViewTapped:(UITapGestureRecognizer*)recognizer {
    [self.navigationController setNavigationBarHidden: ! self.navigationController.isNavigationBarHidden animated: YES];
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
    [self updateZoomScale];
}

- (void) setImage:(UIImage *)image {
    _image = image;
    if (self.view && _image) {
        [self updateZoomScale];
    }
}

@end
