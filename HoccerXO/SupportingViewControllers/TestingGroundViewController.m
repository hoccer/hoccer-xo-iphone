//
//  TestingGroundViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TestingGroundViewController.h"

#import "HXOChattyLabel.h"

@interface TestingGroundViewController ()

@end

@implementation TestingGroundViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSError * error = nil;

    /*
    // found at http://regexlib.com/REDetails.aspx?regexp_id=96
    NSString * httpRegEx = @"(http|https)://[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&amp;:/~\\+#]*[\\w\\-\\@?^=%&amp;/~\\+#])?";
    NSRegularExpression * httpRegex = [NSRegularExpression regularExpressionWithPattern: httpRegEx
                                                                                options: NSRegularExpressionCaseInsensitive error: & error];
     */

    NSTextCheckingTypes types = (NSTextCheckingTypes)NSTextCheckingTypeLink;
    if ([[UIDevice currentDevice].model isEqualToString: @"iPhone"]) {
        types |= NSTextCheckingTypePhoneNumber;
    }

    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes: types
                                                               error:&error];
    if (error == nil) {
        [self.label registerTokenClass: @"dataDetector" withExpression: detector style: nil];
    } else {
        NSLog(@"failed to create regex: %@", error);
    }

    self.label.text = @"http://gnurbel.com 😃👍👠 Deine kostenlose Messenger App!\nUnbegrenzter Datentransfer – sicher, zuverlässig und schnell\n\nHoccer XO ist dein persönlicher Dienst zur Übermittlung von Texten, Bildern, Audio, Video, Adressen und Standorten, die du mit deinen Freunden und Bekannten austauschen möchtest. https://example.com/with/very/longish/url/path Der Schutz deiner Privatsphäre steht hierbei im Mittelpunkt. Deine Nachrichten sind vom Sender bis zum Empfänger verschlüsselt. Hoccer XO bietet damit einen Sicherheitsvorteil gegenüber vielen anderen Messenger Diensten. Auch wir bei Hoccer können deine Nachrichten nicht lesen. Deine Kontakte und Telefonbucheintragungen verbleiben ebenfalls bei dir und können von uns weder genutzt noch eingesehen werden. 030 45025958";

}

- (void) chattyLabel:(HXOChattyLabel *)label didTapToken:(NSTextCheckingResult *)match ofClass:(id)tokenClass {
    switch (match.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"tapped link %@", match.URL);
            [[UIApplication sharedApplication] openURL: match.URL];
            break;
        case NSTextCheckingTypePhoneNumber:
            NSLog(@"tapped phone number %@", match.phoneNumber);
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", match.phoneNumber]]];
            break;
        default:
            NSLog(@"tapped unhandled token '%@' of type %@", [label.text substringWithRange: match.range], tokenClass);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
