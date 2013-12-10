//
//  TestingGroundViewController.m
//  HoccerXO
//
//  Created by David Siegel on 05.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TestingGroundViewController.h"

#import "UIAlertView+BlockExtensions.h"

#import "HXOLinkyLabel.h"
#import "BubbleViewToo.h"
#import "InsetImageView2.h"
#import "HXOUserDefaults.h"

@interface TestingGroundViewController ()

@end

@interface BubbleItem : NSObject

@property (nonatomic,assign) HXOBubbleColorScheme       colorScheme;
@property (nonatomic,assign) HXOMessageDirection        pointDirection;
@property (nonatomic,strong) NSString *                 cellIdentifier;
@property (nonatomic,strong) NSString *                 text;
@property (nonatomic,strong) UIImage  *                 previewImage;
@property (nonatomic,assign) CGFloat                    imageAspect;
@property (nonatomic,assign) HXOAttachmentStyle         attachmentStyle;
//@property (nonatomic,strong) UIImage *                  smallAttachmentTypeIcon;
@property (nonatomic,strong) UIImage *                  largeAttachmentTypeIcon;
@property (nonatomic,strong) NSString *                 attachmentText;
@property (nonatomic,assign) HXOAttachmentTranserState  attachmentTransferState;
@property (nonatomic,assign) float                      progress;
@property (nonatomic,assign) HXOBubbleRunButtonStyle    runButtonStyle;

@end

@implementation TestingGroundViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [CrappyTextMessageCell class]];
    [self registerCellClass: [CrappyAttachmentMessageCell class]];
    [self registerCellClass: [CrappyAttachmentWithTextMessageCell class]];

    BubbleItem * i0 = [[BubbleItem alloc] init];
    i0.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i0.colorScheme = HXOBubbleColorSchemeIncoming;
    i0.pointDirection = HXOMessageDirectionIncoming;
    i0.text = @"Icing tiramisu apple pie carrot cake by http://cupcakeipsum.com";

    BubbleItem * i1 = [[BubbleItem alloc] init];
    i1.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i1.colorScheme = HXOBubbleColorSchemeInProgress;
    i1.text = @"Candy cupcake cupcake toffee danish cotton candy cookie wafer by http://cupcakeipsum.com";

    BubbleItem * i2 = [[BubbleItem alloc] init];
    i2.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i2.colorScheme = HXOBubbleColorSchemeSuccess;
    i2.text = @"Oat cake dragée tiramisu.";

    BubbleItem * i3 = [[BubbleItem alloc] init];
    i3.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i3.colorScheme = HXOBubbleColorSchemeFailed;
    i3.text = @"Oat cake dragée tiramisu. Icing tiramisu apple pie carrot cake.";

    BubbleItem * i4 = [[BubbleItem alloc] init];
    i4.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i4.colorScheme = HXOBubbleColorSchemeSuccess;
    i4.pointDirection = HXOMessageDirectionOutgoing;
    i4.text = @"Oat 🍰 dragée tiramisu. Icing tiramisu 🍎 pie carrot 🍰.";

    BubbleItem * i5 = [[BubbleItem alloc] init];
    i5.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i5.colorScheme = HXOBubbleColorSchemeIncoming;
    i5.pointDirection = HXOMessageDirectionIncoming;
    i5.text = @"Icing tiramisu 🍎 pie carrot 🍰.";

    BubbleItem * i6 = [[BubbleItem alloc] init];
    i6.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i6.colorScheme = HXOBubbleColorSchemeSuccess;
    i6.pointDirection = HXOMessageDirectionOutgoing;
    i6.text = @"Cheesecake toffee jelly-o chocolate bar chocolate powder applicake tootsie roll. Applicake sweet roll tiramisu dragée muffin. Gummies marzipan apple pie brownie candy by http://cupcakeipsum.com";

    BubbleItem * i7 = [[BubbleItem alloc] init];
    i7.cellIdentifier = [CrappyTextMessageCell reuseIdentifier];
    i7.colorScheme = HXOBubbleColorSchemeIncoming;
    i7.pointDirection = HXOMessageDirectionIncoming;
    i7.text = @"Chocolate cake danish tart ice cream. 030 87654321"; // Lemon drops apple pie jujubes pie apple pie pie applicake. Lemon drops biscuit candy. Soufflé soufflé toffee cupcake lollipop jujubes. Chocolate cake chocolate apple pie carrot cake. Chocolate cake danish cupcake lemon drops cake marshmallow. Chupa chups tiramisu gingerbread fruitcake pie oat cake cotton candy sesame snaps gingerbread. Lemon drops tootsie roll sugar plum marshmallow croissant chocolate bar. Gummi bears jelly lollipop marzipan bonbon. Brownie unerdwear.com lemon drops marzipan cookie dragée chupa chups. Bear claw sesame snaps jujubes wafer. Dragée gummi bears lollipop carrot cake by http://cupcakeipsum.com 030 87654321";

    BubbleItem * i8 = [[BubbleItem alloc] init];
    i8.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i8.colorScheme = HXOBubbleColorSchemeSuccess;
    i8.pointDirection = HXOMessageDirectionOutgoing;
    i8.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i8.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i8.attachmentText = @"cupcakes.jpg";
    i8.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i8.progress = 0.90;

    BubbleItem * i9 = [[BubbleItem alloc] init];
    i9.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i9.colorScheme = HXOBubbleColorSchemeIncoming;
    i9.pointDirection = HXOMessageDirectionIncoming;
    i9.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i9.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i9.attachmentText = @"cupcakes.jpg";
    i9.runButtonStyle = HXOBubbleRunButtonPlay;
    i9.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i9.progress = 1.0;


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

    BubbleItem * i12 = [[BubbleItem alloc] init];
    i12.cellIdentifier = [CrappyAttachmentMessageCell reuseIdentifier];
    i12.colorScheme = HXOBubbleColorSchemeFailed;
    i12.pointDirection = HXOMessageDirectionOutgoing;
    i12.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i12.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_music"];
    i12.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-music"];
    i12.attachmentText = @"Cool Song";

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
    CGSize imageSize = [UIImage imageNamed:@"cupcakes.jpg"].size;
    i14.imageAspect = imageSize.width / imageSize.height;
    i14.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i14.progress = 0.5;

    BubbleItem * i15 = [[BubbleItem alloc] init];
    i15.cellIdentifier = [CrappyAttachmentWithTextMessageCell reuseIdentifier];
    i15.colorScheme = HXOBubbleColorSchemeIncoming;
    i15.pointDirection = HXOMessageDirectionIncoming;
    i15.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i15.imageAspect = imageSize.width / imageSize.height;
    i15.attachmentTransferState = HXOAttachmentTransferStateInProgress;
    i15.progress = 0.5;
    i15.text = @"Icing tiramisu apple pie carrot cake by http://cupcakeipsum.com";


    BubbleItem * i16 = [[BubbleItem alloc] init];
    i16.cellIdentifier = [CrappyAttachmentWithTextMessageCell reuseIdentifier];
    i16.colorScheme = HXOBubbleColorSchemeFailed;
    i16.pointDirection = HXOMessageDirectionOutgoing;
    i16.attachmentStyle = HXOAttachmentStyleThumbnail;
    //i16.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_contact"];
    i16.largeAttachmentTypeIcon = [UIImage imageNamed:@"cnt-contact"];
    i16.attachmentText = @"Some Dude";
    i16.text = @"Oat cake dragée tiramisu. .";


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

    _items = @[i0, i1, i2, i3, i4, i5, i6, i7,
               i8, i9, i10, i11, i12, i13, i14,
               i15, i16, i17, i18];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];

}

- (void)defaultsChanged:(NSNotification*)aNotification {
    NSLog(@"defaultsChanged testingGround: %@", aNotification);
    //[self updateVisibleCells];
    [self.tableView reloadData];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.tableView reloadData];
}

- (void) registerTokenClasses: (HXOLinkyLabel*) label {

    NSError * error = nil;
    NSTextCheckingTypes types = (NSTextCheckingTypes)NSTextCheckingTypeLink;
    if ([[UIDevice currentDevice].model isEqualToString: @"iPhone"]) {
        types |= NSTextCheckingTypePhoneNumber;
    }

    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes: types
                                                               error:&error];
    if (error == nil) {
        [label registerTokenClass: @"dataDetector" withExpression: detector style: nil];
    } else {
        NSLog(@"failed to create regex: %@", error);
    }
}

- (void) chattyLabel:(HXOLinkyLabel *)label didTapToken:(NSTextCheckingResult *)match ofClass:(id)tokenClass isLongPress:(BOOL)isLongPress {
    switch (match.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"tapped link %@", match.URL);
            [[UIApplication sharedApplication] openURL: match.URL];
            break;
        case NSTextCheckingTypePhoneNumber:
            NSLog(@"tapped phone number %@", match.phoneNumber);
            [self makePhoneCall: match.phoneNumber];
            break;
        default:
            NSLog(@"tapped unhandled token '%@' of type %@", [label.text substringWithRange: match.range], tokenClass);
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
    BubbleViewToo * cell = [_cellPrototypes objectForKey: item.cellIdentifier];
    [self configureCell: cell item: item];
    return [cell calculateHeightForWidth: self.tableView.bounds.size.width];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BubbleItem * item = _items[indexPath.row];
    BubbleViewToo * cell = (BubbleViewToo*)[self.tableView dequeueReusableCellWithIdentifier: [item cellIdentifier] forIndexPath: indexPath];
    cell.colorScheme = item.colorScheme;
    cell.messageDirection = item.pointDirection;
    [cell.avatar setImage:[UIImage imageNamed: @"cupcakes.jpg"] forState: UIControlStateNormal];
    cell.subtitle.text = @"Someone";
    [self configureCell: cell item: item];
    return cell;
}

- (void) configureCell: (BubbleViewToo*) cell item: (BubbleItem*) item {
    if ([item.cellIdentifier isEqualToString: [CrappyTextMessageCell reuseIdentifier]]) {
        [self configureTextCell: (CrappyTextMessageCell*)cell item: item];
    } else if ([item.cellIdentifier isEqualToString: [CrappyAttachmentMessageCell reuseIdentifier]]) {
        [self configureAttachmentCell: (CrappyAttachmentMessageCell*)cell item: item];
    } else if ([item.cellIdentifier isEqualToString: [CrappyAttachmentWithTextMessageCell reuseIdentifier]]) {
        [self configureAttachmentCell: (CrappyAttachmentMessageCell*)cell item: item];
        [self configureTextCell: cell item: item];
    }
}

- (void) configureTextCell: (id) cell item: (BubbleItem*) item {
    if ([cell label].tokenClasses.count == 0) {
        [self registerTokenClasses: [cell label]];
        [cell label].delegate = self;
    }
    double fontSize = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMessageFontSize] doubleValue];
    [cell label].font = [UIFont systemFontOfSize: fontSize];
    [cell label].text = item.text;
}

- (void) configureAttachmentCell: (CrappyAttachmentMessageCell*) cell item: (BubbleItem*) item {
    cell.previewImage = item.previewImage;
    cell.imageAspect = item.imageAspect;
    cell.attachmentStyle = item.attachmentStyle;
    //cell.smallAttachmentTypeIcon = item.smallAttachmentTypeIcon;
    cell.largeAttachmentTypeIcon = item.largeAttachmentTypeIcon;
    cell.attachmentTransferState = item.attachmentTransferState;
    cell.progressBar.progress = item.progress;
    cell.runButtonStyle = item.runButtonStyle;

    NSString * title = item.attachmentText;
    NSMutableAttributedString * attributedTitle;
    NSString * fileExtension = [title pathExtension];
    if (title != nil) {
        if (item.attachmentTransferState == HXOAttachmentTransferStateInProgress) {
            NSDictionary * attributes = @{NSForegroundColorAttributeName: [UIColor colorWithWhite: 0.5 alpha:1.0]};
            attributedTitle = [[NSMutableAttributedString alloc] initWithString: title attributes: attributes];
        } else if ( ! [fileExtension isEqualToString: @""]) {
            attributedTitle = [[NSMutableAttributedString alloc] initWithString: title];
            NSRange range = NSMakeRange(title.length - (fileExtension.length + 1), fileExtension.length + 1);
            [attributedTitle addAttribute: NSForegroundColorAttributeName value: [UIColor colorWithWhite: 0.5 alpha: 1.0] range: range];
        } else {
            attributedTitle = [[NSMutableAttributedString alloc] initWithString: title];
        }
    }

    cell.attachmentTitle.attributedText = attributedTitle;
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

