//
//  AudioPlayerStateController.m
//  HoccerXO
//
//  Created by guido on 21.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "AudioPlayerStateItemController.h"
#import "navbar-playing.h"
#import "HXOAudioPlayer.h"

@interface AudioPlayerStateItemController ()

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) UIBarButtonItem *barButtonItem;

@end

@implementation AudioPlayerStateItemController

- (id) initWithViewController: (UIViewController *) viewController {
    self = [super init];
    
    if (self) {
        self.viewController = viewController;
        [self updatePlaybackState];
        [[HXOAudioPlayer sharedInstance] addObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying)) options:0 context:NULL];
    }
    
    return self;
}

- (void) dealloc {
    [[HXOAudioPlayer sharedInstance] removeObserver:self forKeyPath:NSStringFromSelector(@selector(isPlaying))];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context {
    [self updatePlaybackState];
}

- (void) onClick: (id) sender {
    UIViewController *audioPlayerViewController = [self.viewController.storyboard instantiateViewControllerWithIdentifier:@"AudioPlayerViewController"];
    [self.viewController presentViewController:audioPlayerViewController animated:YES completion:NULL];
}

- (void) updatePlaybackState {
    NSMutableArray *navBarButtons = [NSMutableArray arrayWithArray:self.viewController.navigationItem.rightBarButtonItems];

    if ([[HXOAudioPlayer sharedInstance] isPlaying]) {
        if (![navBarButtons containsObject:self.barButtonItem]) {
            [navBarButtons addObject:self.barButtonItem];
            
            if (navBarButtons.count > 1) {
                // HACK: reduce margin to right neighbor by using a negative image inset
                self.barButtonItem.imageInsets = UIEdgeInsetsMake(0, 0, 0, -18);
            } else {
                self.barButtonItem.imageInsets = UIEdgeInsetsMake(0, 0, 0, 0);
            }
        }
    } else {
        if ([navBarButtons containsObject:self.barButtonItem]) {
            [navBarButtons removeObject:self.barButtonItem];
        }
    }

    self.viewController.navigationItem.rightBarButtonItems = navBarButtons;
}

- (UIBarButtonItem *) barButtonItem {
    if (_barButtonItem == nil) {
        //UIImage *image = [UIImage imageNamed:@"navbar-music-is-playing"];
        UIImage *image = [[navbar_playing alloc] init].image;
        _barButtonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(onClick:)];
    }

    return _barButtonItem;
}

@end
