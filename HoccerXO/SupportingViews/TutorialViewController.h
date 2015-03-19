//
//  TutorialViewController.h
//  HoccerXO
//
//  Created by David Siegel on 19.03.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TutorialViewController : UIViewController

@property (nonatomic, strong) IBOutlet UITextView * textView;
@property (nonatomic, strong) NSAttributedString * text;

@end
