//
//  TestingGroundViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TestingGroundViewController.h"

#import "UIAlertView+BlockExtensions.h"

#import "TextMessageCell.h"
#import "ImageAttachmentMessageCell.h"
#import "GenericAttachmentMessageCell.h"
#import "ImageAttachmentWithTextMessageCell.h"
#import "GenericAttachmentWithTextMessageCell.h"
#import "ImageAttachmentSection.h"
#import "TextSection.h"
#import "GenericAttachmentSection.h"
#import "InsetImageView2.h"
#import "HXOUserDefaults.h"

@interface TestingGroundViewController ()

@end

@interface BubbleItem : NSObject

@property (nonatomic,assign) HXOBubbleColorScheme       colorScheme;
@property (nonatomic,assign) HXOMessageDirection        pointDirection;
@property (nonatomic,strong) NSString *                 cellIdentifier;
@property (nonatomic,strong) NSAttributedString *                 text;
@property (nonatomic,strong) UIImage  *                 previewImage;
@property (nonatomic,assign) CGFloat                    imageAspect;
//@property (nonatomic,assign) HXOAttachmentStyle         attachmentStyle;
//@property (nonatomic,strong) UIImage *                  smallAttachmentTypeIcon;
@property (nonatomic,strong) UIImage *                  largeAttachmentTypeIcon;
@property (nonatomic,strong) NSString *                 attachmentText;
//@property (nonatomic,assign) HXOAttachmentTranserState  attachmentTransferState;
@property (nonatomic,assign) float                      progress;
//@property (nonatomic,assign) HXOBubbleRunButtonStyle    runButtonStyle;

@end

@implementation TestingGroundViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSMutableAttributedString * text = [[NSMutableAttributedString alloc] initWithString: @"Candy cupcake cupcake toffee danish cotton candy cookie wafer by http://cupcakeipsum.com"];

    NSError * error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes: NSTextCheckingTypeLink
                                                               error:&error];

    [text addLinksMatching: detector];

    self.label.attributedText = text;
    self.label.backgroundColor = [UIColor orangeColor];
    self.label.delegate = self;

    [self registerCellClass: [TextMessageCell class]];
    [self registerCellClass: [ImageAttachmentMessageCell class]];
    [self registerCellClass: [GenericAttachmentMessageCell class]];
    [self registerCellClass: [ImageAttachmentWithTextMessageCell class]];
    [self registerCellClass: [GenericAttachmentWithTextMessageCell class]];

    BubbleItem * i0 = [[BubbleItem alloc] init];
    i0.cellIdentifier = [TextMessageCell reuseIdentifier];
    i0.colorScheme = HXOBubbleColorSchemeIncoming;
    i0.pointDirection = HXOMessageDirectionIncoming;
    i0.text = [self addLinks: @"Icing tiramisu"];

    BubbleItem * i1 = [[BubbleItem alloc] init];
    i1.cellIdentifier = [TextMessageCell reuseIdentifier];
    i1.colorScheme = HXOBubbleColorSchemeInProgress;
    i1.text = [self addLinks: @"Candy cupcake cupcake toffee danish cotton candy cookie wafer by http://cupcakeipsum.com"];

    BubbleItem * i2 = [[BubbleItem alloc] init];
    i2.cellIdentifier = [TextMessageCell reuseIdentifier];
    i2.colorScheme = HXOBubbleColorSchemeSuccess;
    i2.text = [self addLinks: @"Oat cake dragée tiramisu."];

    BubbleItem * i3 = [[BubbleItem alloc] init];
    i3.cellIdentifier = [TextMessageCell reuseIdentifier];
    i3.colorScheme = HXOBubbleColorSchemeFailed;
    i3.text = [self addLinks: @"Oat cake dragée tiramisu. Icing tiramisu apple pie carrot cake."];

    BubbleItem * i4 = [[BubbleItem alloc] init];
    i4.cellIdentifier = [TextMessageCell reuseIdentifier];
    i4.colorScheme = HXOBubbleColorSchemeSuccess;
    i4.pointDirection = HXOMessageDirectionOutgoing;
    i4.text = [self addLinks: @"Oat 🍰 dragée tiramisu. Icing tiramisu 🍎 pie carrot 🍰."];

    BubbleItem * i5 = [[BubbleItem alloc] init];
    i5.cellIdentifier = [TextMessageCell reuseIdentifier];
    i5.colorScheme = HXOBubbleColorSchemeIncoming;
    i5.pointDirection = HXOMessageDirectionIncoming;
    i5.text = [self addLinks: @"Icing tiramisu 🍎 pie carrot 🍰."];

    BubbleItem * i6 = [[BubbleItem alloc] init];
    i6.cellIdentifier = [TextMessageCell reuseIdentifier];
    i6.colorScheme = HXOBubbleColorSchemeSuccess;
    i6.pointDirection = HXOMessageDirectionOutgoing;
    i6.text = [self addLinks:@"Cheesecake toffee jelly-o chocolate bar chocolate powder applicake tootsie roll. Applicake sweet roll tiramisu dragée muffin. Gummies marzipan apple pie brownie candy by http://cupcakeipsum.com"];

    BubbleItem * i7 = [[BubbleItem alloc] init];
    i7.cellIdentifier = [TextMessageCell reuseIdentifier];
    i7.colorScheme = HXOBubbleColorSchemeIncoming;
    i7.pointDirection = HXOMessageDirectionIncoming;
    i7.text = [self addLinks: @"Chocolate cake danish tart ice cream. 030 87654321"]; // Lemon drops apple pie jujubes pie apple pie pie applicake. Lemon drops biscuit candy. Soufflé soufflé toffee cupcake lollipop jujubes. Chocolate cake chocolate apple pie carrot cake. Chocolate cake danish cupcake lemon drops cake marshmallow. Chupa chups tiramisu gingerbread fruitcake pie oat cake cotton candy sesame snaps gingerbread. Lemon drops tootsie roll sugar plum marshmallow croissant chocolate bar. Gummi bears jelly lollipop marzipan bonbon. Brownie unerdwear.com lemon drops marzipan cookie dragée chupa chups. Bear claw sesame snaps jujubes wafer. Dragée gummi bears lollipop carrot cake by http://cupcakeipsum.com 030 87654321"];

    BubbleItem * i8 = [[BubbleItem alloc] init];
    i8.cellIdentifier = [ImageAttachmentMessageCell reuseIdentifier];
    i8.colorScheme = HXOBubbleColorSchemeSuccess;
    i8.pointDirection = HXOMessageDirectionOutgoing;
    i8.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
//    i8.attachmentStyle = HXOAttachmentStyleOriginalAspect;
//    i8.attachmentText = @"cupcakes.jpg";
//    i8.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i8.progress = 0.90;

    BubbleItem * i9 = [[BubbleItem alloc] init];
    i9.cellIdentifier = [ImageAttachmentMessageCell reuseIdentifier];
    i9.colorScheme = HXOBubbleColorSchemeIncoming;
    i9.pointDirection = HXOMessageDirectionIncoming;
    CGSize imageSize = [UIImage imageNamed:@"cupcakes.jpg"].size;
    i9.imageAspect = imageSize.width / imageSize.height;
    //i9.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    //i9.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i9.attachmentText = @"cupcakes.jpg";
    //i9.runButtonStyle = HXOBubbleRunButtonPlay;
    //i9.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i9.progress = 1.0;

/*
    BubbleItem * i10 = [[BubbleItem alloc] init];
    i10.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i10.colorScheme = HXOBubbleColorSchemeSuccess;
    i10.pointDirection = HXOMessageDirectionOutgoing;
    i10.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i10.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_image"];
    i10.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-photo"];
    i10.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i10.attachmentText = @"cupcakes.jpg";
    i10.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i10.progress = 0.33;

    BubbleItem * i11 = [[BubbleItem alloc] init];
    i11.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i11.colorScheme = HXOBubbleColorSchemeIncoming;
    i11.pointDirection = HXOMessageDirectionIncoming;
    i11.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i11.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_image"];
    i11.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-photo"];
    i11.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i11.attachmentText = @"cupcakes.jpg";
*/
    BubbleItem * i12 = [[BubbleItem alloc] init];
    i12.cellIdentifier = [GenericAttachmentMessageCell reuseIdentifier];
    i12.colorScheme = HXOBubbleColorSchemeSuccess;
    i12.pointDirection = HXOMessageDirectionOutgoing;
    //i12.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i12.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_music"];
    i12.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-music"];
    i12.attachmentText = @"Cool Song";
/*
    BubbleItem * i13 = [[BubbleItem alloc] init];
    i13.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i13.colorScheme = HXOBubbleColorSchemeIncoming;
    i13.pointDirection = HXOMessageDirectionIncoming;
    i13.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i13.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_location"];
    i13.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-location"];
    i13.attachmentText = @"Nice Place";
    i13.attachmentTransferState = HXOAttachmentTransferStateInProgress;

    BubbleItem * i14 = [[BubbleItem alloc] init];
    i14.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i14.colorScheme = HXOBubbleColorSchemeIncoming;
    i14.pointDirection = HXOMessageDirectionIncoming;
    i14.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i14.imageAspect = imageSize.width / imageSize.height;
    i14.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i14.progress = 0.5;
*/
    BubbleItem * i15 = [[BubbleItem alloc] init];
    i15.cellIdentifier = [ImageAttachmentWithTextMessageCell reuseIdentifier];
    i15.colorScheme = HXOBubbleColorSchemeIncoming;
    i15.pointDirection = HXOMessageDirectionIncoming;
    //i15.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i15.previewImage = [UIImage imageNamed: @"cupcakes.jpg"];
    //i15.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i15.progress = 0.5;
    i15.text = [self addLinks: @"Icing tiramisu apple pie carrot cake by http://cupcakeipsum.com"];


    BubbleItem * i16 = [[BubbleItem alloc] init];
    i16.cellIdentifier = [GenericAttachmentWithTextMessageCell reuseIdentifier];
    i16.colorScheme = HXOBubbleColorSchemeFailed;
    i16.pointDirection = HXOMessageDirectionOutgoing;
    //i16.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i16.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_contact"];
    i16.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-contact"];
    i16.attachmentText = @"Some Dude";
    i16.text = [self addLinks: @"Oat cake dragée tiramisu. ."];
/*

    BubbleItem * i17 = [[BubbleItem alloc] init];
    i17.cellIdentifier = [CrappyAttachmentWithTextMessageCell reuseIdentifier];
    i17.colorScheme = HXOBubbleColorSchemeSuccess;
    i17.pointDirection = HXOMessageDirectionOutgoing;
    i17.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i17.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_voice"];
    i17.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-record"];
    i17.attachmentText = @"Recording 1";
    i17.text = @"Oat 🍰 dragée tiramisu. Icing tiramisu 🍎 pie carrot 🍰.";

    BubbleItem * i18 = [[BubbleItem alloc] init];
    i18.cellIdentifier = [CrappyAttachmentWithTextMessageCell reuseIdentifier];
    i18.colorScheme = HXOBubbleColorSchemeInProgress;
    i18.pointDirection = HXOMessageDirectionOutgoing;
    i18.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i18.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_video"];
    i18.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-video"];
    i18.attachmentText = @"Classic Movie";
    i18.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i18.text = @"Cheesecake toffee jelly-o chocolate bar chocolate powder applicake tootsie roll. Applicake sweet roll tiramisu dragée muffin. Gummies marzipan apple pie brownie candy by http://cupcakeipsum.com";
*/
    _items = @[i0, i1, i2, i3, i4, i5, i6, i7,
               i8, i9,/* i10, i11,*/i12/*, i13, i14*/,
               i15, i16/*, i17, i18*/];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];

}

- (NSAttributedString*) addLinks: (NSString*) text {
    NSMutableAttributedString * string = [[NSMutableAttributedString alloc] initWithString: text];

    NSError * error = nil;
    NSTextCheckingTypes types = (NSTextCheckingTypes)NSTextCheckingTypeLink;
    if ([[UIDevice currentDevice].model isEqualToString: @"iPhone"]) {
        types |= NSTextCheckingTypePhoneNumber;
    }

    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes: types
                                                               error:&error];
    if (error == nil) {
        NSArray * links = [detector matchesInString: text options: 0 range: NSMakeRange(0, text.length)];
        for (NSTextCheckingResult* link in links) {
            [string addAttribute: kHXOLinkAttributeName value: link range: link.range];
        }
    } else {
        NSLog(@"failed to create regex: %@", error);
    }

    return string;
}

- (void)defaultsChanged:(NSNotification*)aNotification {
    NSLog(@"defaultsChanged testingGround: %@", aNotification);
    //[self updateVisibleCells];
    [self.tableView reloadData];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.tableView reloadData];
}

- (void) hyperLabel:(HXOHyperLabel *)label didPressLink:(NSTextCheckingResult*)link long:(BOOL)longPress {
    switch (link.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"tapped link %@", link.URL);
            [[UIApplication sharedApplication] openURL: link.URL];
            break;
        case NSTextCheckingTypePhoneNumber:
            NSLog(@"tapped phone number %@", link.phoneNumber);
            [self makePhoneCall: link.phoneNumber];
            break;
        default:
            NSLog(@"tapped unhandled token '%@'", [label.attributedText.string substringWithRange: link.range]);
    }
}

- (void) makePhoneCall: (NSString*) phoneNumber {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle: phoneNumber
                                                     message: nil
                                             completionBlock:^(NSUInteger buttonIndex, UIAlertView *alertView) {
                                                 if (buttonIndex != alertView.cancelButtonIndex) {
                                                     NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [phoneNumber stringByReplacingOccurrencesOfString:@" " withString:@"-"]]];
                                                     [[UIApplication sharedApplication] openURL: url];
                                                 }
                                             }
                                           cancelButtonTitle: NSLocalizedString(@"Cancel", nil)
                                           otherButtonTitles: NSLocalizedString(@"button_title_call", nil), nil];
    [alert show];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View Delegate and Datasource

- (void) registerCellClass: (Class) cellClass {
    [self.tableView registerClass: cellClass forCellReuseIdentifier: [cellClass reuseIdentifier]];
    BubbleViewToo * prototype = [[cellClass alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier: [cellClass reuseIdentifier]];
    //    HXOTableViewCell * prototype = [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier]];
    if (_cellPrototypes == nil) {
        _cellPrototypes = [NSMutableDictionary dictionary];
    }
    [_cellPrototypes setObject: prototype forKey: [cellClass reuseIdentifier]];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _items.count;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BubbleItem * item = _items[indexPath.row];
    MessageCell * cell = [_cellPrototypes objectForKey: item.cellIdentifier];
    [self configureCell: cell item: item];
    return [cell sizeThatFits: CGSizeMake(self.tableView.bounds.size.width, FLT_MAX)].height;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BubbleItem * item = _items[indexPath.row];
    MessageCell * cell = (MessageCell*)[self.tableView dequeueReusableCellWithIdentifier: [item cellIdentifier] forIndexPath: indexPath];
    cell.colorScheme = item.colorScheme;
    cell.messageDirection = item.pointDirection;
    [cell.avatar setImage:[UIImage imageNamed: @"cupcakes.jpg"] forState: UIControlStateNormal];
    cell.subtitle.text = @"Someone";
    [self configureCell: cell item: item];
    return cell;
}

- (void) configureCell: (MessageCell*) cell item: (BubbleItem*) item {
    for (MessageSection * section in cell.sections) {
        if ([section isKindOfClass: [TextSection class]]) {
            [self configureTextSection: (TextSection*)section item: item];
        } else if ([section isKindOfClass: [ImageAttachmentSection class]]) {
            [self configureImageAttachmentSection: (ImageAttachmentSection*)section item: item];
        } else if ([section isKindOfClass: [GenericAttachmentSection class]]) {
            [self configureGenericAttachmentSection: (GenericAttachmentSection*)section item: item];
        }
    }
}

- (void) configureTextSection: (TextSection*) section item: (BubbleItem*) item {
    double fontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
    section.label.font = [UIFont systemFontOfSize: fontSize];
    section.label.attributedText = item.text;
}

- (void) configureAttachmentSection: (AttachmentSection*) section item: (BubbleItem*) item {
    section.subtitle.text = nil; // TODO ...
    // TODO: progress setup goes here
}


- (void) configureImageAttachmentSection: (ImageAttachmentSection*) section item: (BubbleItem*) item {
    [self configureAttachmentSection: section item: item];
    section.imageAspect = item.imageAspect;
    section.image = item.previewImage;

/*
    cell.attachmentStyle = item.attachmentStyle;
    //cell.smallAttachmentTypeIcon = item.smallAttachmentTypeIcon;
    cell.largeAttachmentTypeIcon = item.largeAttachmentTypeIcon;
    cell.attachmentTransferState = item.attachmentTransferState;
    cell.progressBar.progress = item.progress;
    cell.runButtonStyle = item.runButtonStyle;

 */
}

- (void) configureGenericAttachmentSection: (GenericAttachmentSection*) section item: (BubbleItem*) item {
    [self configureAttachmentSection: section item: item];

    section.title.text = item.attachmentText;
}


@end

@implementation BubbleItem

- (id) init {
    self = [super init];
    if (self != nil) {
        self.pointDirection = HXOMessageDirectionOutgoing;
        self.colorScheme = HXOBubbleColorSchemeSuccess;
    }
    return self;
}
@end

