//
//  TestingGroundViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TestingGroundViewController.h"

#import "HXOLinkyLabel.h"

#import "BubbleViewToo.h"

@interface TestingGroundViewController ()

@end

@interface BubbleItem : NSObject

@property (nonatomic,assign) HXOBubbleColorScheme colorScheme;
@property (nonatomic,assign) HXOMessageDirection  pointDirection;
@property (nonatomic,assign) CGFloat              height;
@property (nonatomic,strong) NSString *           cellIdentifier;
@property (nonatomic,strong) NSString *           text;

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

    //self.label.text = @"http://google.com 😃👍👠 Deine kostenlose Messenger App!\nUnbegrenzter Datentransfer – sicher, zuverlässig und schnell\n\nHoccer XO ist dein persönlicher Dienst zur Übermittlung von Texten, Bildern, Audio, Video, Adressen und Standorten, die du mit deinen Freunden und Bekannten austauschen möchtest. https://server.talk.hoccer.de/status Der Schutz deiner Privatsphäre steht hierbei im Mittelpunkt. Deine Nachrichten sind vom Sender bis zum Empfänger verschlüsselt. Hoccer XO bietet damit einen Sicherheitsvorteil gegenüber vielen anderen Messenger Diensten. https://github.com/hoccer/hoccer-xo-iphone/blob/master/HoccerXO/Assets/ChatView/ChatBar/chatbar_bg_noise%402x.png Auch wir bei Hoccer können deine Nachrichten nicht lesen. Deine Kontakte und Telefonbucheintragungen verbleiben ebenfalls bei dir und können von uns weder genutzt noch eingesehen werden. 030 87654321";


    self.label.shadowColor = [UIColor colorWithWhite: 0.8 alpha: 1.0];
    self.label.shadowOffset = CGSizeMake(0, 1);
    
    //self.label.text = @"Lorem Ipsum 😃👍👠. Der Schutz deiner Privatsphäre steht hierbei im Mittelpunkt. 👠 Deine Nachrichten sind vom Sender bis http://google.com";
    //self.label.text = @"Lorem Ipsum. Der Schutz deiner Privatsphäre steht hierbei im Mittelpunkt. Deine Nachrichten sind vom Sender bis http://google.com";

    self.label.backgroundColor = [UIColor orangeColor];

    //[self.label sizeToFit];

    [self.tableView registerClass: [TextMessageCell class] forCellReuseIdentifier: [TextMessageCell reuseIdentifier]];

    BubbleItem * i0 = [[BubbleItem alloc] init];
    i0.cellIdentifier = [TextMessageCell reuseIdentifier];
    i0.colorScheme = HXOBubbleColorSchemeWhite;
    i0.pointDirection = HXOMessageDirectionIncoming;
    i0.height = 48 + 2 * 8;
    i0.text = @"Icing tiramisu apple pie carrot cake.";

    BubbleItem * i1 = [[BubbleItem alloc] init];
    i1.cellIdentifier = [TextMessageCell reuseIdentifier];
    i1.colorScheme = HXOBubbleColorSchemeEtched;
    i1.height = 48 + 2 * 8;
    i1.text = @"Candy cupcake cupcake toffee danish cotton candy cookie wafer.";

    BubbleItem * i2 = [[BubbleItem alloc] init];
    i2.cellIdentifier = [TextMessageCell reuseIdentifier];
    i2.colorScheme = HXOBubbleColorSchemeBlue;
    i2.height = 48 + 2 * 8;
    i2.text = @"Oat cake dragée tiramisu.";

    BubbleItem * i3 = [[BubbleItem alloc] init];
    i3.cellIdentifier = [TextMessageCell reuseIdentifier];
    i3.colorScheme = HXOBubbleColorSchemeRed;
    i3.height = 48 + 2 * 8;
    i3.text = @"Oat cake dragée tiramisu. Icing tiramisu apple pie carrot cake.";

/*
    BubbleItem * i4 = [[BubbleItem alloc] init];
    i4.colorScheme = HXOBubbleColorSchemeBlack;
    i4.pointDirection = HXOMessageDirectionIncoming;
    i4.height = 200;
*/
    _items = @[i0, i1, i2, i3/*, i4*/];
}

- (void) chattyLabel:(HXOLinkyLabel *)label didTapToken:(NSTextCheckingResult *)match ofClass:(id)tokenClass {
    NSURL * url;
    switch (match.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"tapped link %@", match.URL);
            url = match.URL;
            break;
        case NSTextCheckingTypePhoneNumber:
            NSLog(@"tapped phone number %@", match.phoneNumber);
            url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [match.phoneNumber stringByReplacingOccurrencesOfString:@" " withString:@"-"]]];
            break;
        default:
            NSLog(@"tapped unhandled token '%@' of type %@", [label.text substringWithRange: match.range], tokenClass);
    }
    if (url != nil) {
        [[UIApplication sharedApplication] openURL: url];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View Delegate and Datasource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return ((BubbleItem*)_items[indexPath.row]).height;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BubbleItem * item = _items[indexPath.row];
    TextMessageCell * cell = (TextMessageCell*)[self.tableView dequeueReusableCellWithIdentifier: [item cellIdentifier] forIndexPath: indexPath];
    cell.colorScheme = item.colorScheme;
    cell.messageDirection = item.pointDirection;
    cell.text = item.text;
    return cell;
}

@end

@implementation BubbleItem

- (id) init {
    self = [super init];
    if (self != nil) {
        self.pointDirection = HXOMessageDirectionOutgoing;
        self.colorScheme = HXOBubbleColorSchemeBlue;
    }
    return self;
}
@end

