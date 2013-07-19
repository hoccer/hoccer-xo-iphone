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
@property (nonatomic,strong) UIImage *                  smallAttachmentTypeIcon;
@property (nonatomic,strong) UIImage *                  largeAttachmentTypeIcon;
@property (nonatomic,strong) NSString *                 attachmentText;
@property (nonatomic,assign) HXOAttachmentTranserState  attachmentTransferState;
@property (nonatomic,assign) float                      progress;

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

    [self registerCellClass: [TextMessageCell class]];
    [self registerCellClass: [AttachmentMessageCell class]];

    BubbleItem * i0 = [[BubbleItem alloc] init];
    i0.cellIdentifier = [TextMessageCell reuseIdentifier];
    i0.colorScheme = HXOBubbleColorSchemeWhite;
    i0.pointDirection = HXOMessageDirectionIncoming;
    i0.text = @"Icing tiramisu apple pie carrot cake by http://cupcakeipsum.com";

    BubbleItem * i1 = [[BubbleItem alloc] init];
    i1.cellIdentifier = [TextMessageCell reuseIdentifier];
    i1.colorScheme = HXOBubbleColorSchemeEtched;
    i1.text = @"Candy cupcake cupcake toffee danish cotton candy cookie wafer by http://cupcakeipsum.com";

    BubbleItem * i2 = [[BubbleItem alloc] init];
    i2.cellIdentifier = [TextMessageCell reuseIdentifier];
    i2.colorScheme = HXOBubbleColorSchemeBlue;
    i2.text = @"Oat cake dragée tiramisu.";

    BubbleItem * i3 = [[BubbleItem alloc] init];
    i3.cellIdentifier = [TextMessageCell reuseIdentifier];
    i3.colorScheme = HXOBubbleColorSchemeRed;
    i3.text = @"Oat cake dragée tiramisu. Icing tiramisu apple pie carrot cake.";

    BubbleItem * i4 = [[BubbleItem alloc] init];
    i4.cellIdentifier = [TextMessageCell reuseIdentifier];
    i4.colorScheme = HXOBubbleColorSchemeBlue;
    i4.pointDirection = HXOMessageDirectionOutgoing;
    i4.text = @"Oat 🍰 dragée tiramisu. Icing tiramisu 🍎 pie carrot 🍰.";

    BubbleItem * i5 = [[BubbleItem alloc] init];
    i5.cellIdentifier = [TextMessageCell reuseIdentifier];
    i5.colorScheme = HXOBubbleColorSchemeWhite;
    i5.pointDirection = HXOMessageDirectionIncoming;
    i5.text = @"Icing tiramisu 🍎 pie carrot 🍰.";

    BubbleItem * i6 = [[BubbleItem alloc] init];
    i6.cellIdentifier = [TextMessageCell reuseIdentifier];
    i6.colorScheme = HXOBubbleColorSchemeBlue;
    i6.pointDirection = HXOMessageDirectionOutgoing;
    i6.text = @"Cheesecake toffee jelly-o chocolate bar chocolate powder applicake tootsie roll. Applicake sweet roll tiramisu dragée muffin. Gummies marzipan apple pie brownie candy by http://cupcakeipsum.com";

    BubbleItem * i7 = [[BubbleItem alloc] init];
    i7.cellIdentifier = [TextMessageCell reuseIdentifier];
    i7.colorScheme = HXOBubbleColorSchemeWhite;
    i7.pointDirection = HXOMessageDirectionIncoming;
    i7.text = @"Chocolate cake danish tart ice cream. 030 87654321"; // Lemon drops apple pie jujubes pie apple pie pie applicake. Lemon drops biscuit candy. Soufflé soufflé toffee cupcake lollipop jujubes. Chocolate cake chocolate apple pie carrot cake. Chocolate cake danish cupcake lemon drops cake marshmallow. Chupa chups tiramisu gingerbread fruitcake pie oat cake cotton candy sesame snaps gingerbread. Lemon drops tootsie roll sugar plum marshmallow croissant chocolate bar. Gummi bears jelly lollipop marzipan bonbon. Brownie unerdwear.com lemon drops marzipan cookie dragée chupa chups. Bear claw sesame snaps jujubes wafer. Dragée gummi bears lollipop carrot cake by http://cupcakeipsum.com 030 87654321";

    BubbleItem * i8 = [[BubbleItem alloc] init];
    i8.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i8.colorScheme = HXOBubbleColorSchemeBlue;
    i8.pointDirection = HXOMessageDirectionOutgoing;
    i8.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i8.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i8.attachmentText = @"cupcakes.jpg";
    i8.attachmentTransferState = HXOAttachmentTranserStateInProgress;
    i8.progress = 0.90;

    BubbleItem * i9 = [[BubbleItem alloc] init];
    i9.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i9.colorScheme = HXOBubbleColorSchemeWhite;
    i9.pointDirection = HXOMessageDirectionIncoming;
    i9.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i9.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    i9.attachmentText = @"cupcakes.jpg";

    BubbleItem * i10 = [[BubbleItem alloc] init];
    i10.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i10.colorScheme = HXOBubbleColorSchemeBlue;
    i10.pointDirection = HXOMessageDirectionOutgoing;
    i10.attachmentStyle = HXOAttachmentStyleThumbnail;
    i10.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_image"];
    i10.largeAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_image"];
    i10.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i10.attachmentText = @"cupcakes.jpg";
    i10.attachmentTransferState = HXOAttachmentTranserStateInProgress;
    i10.progress = 0.33;

    BubbleItem * i11 = [[BubbleItem alloc] init];
    i11.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i11.colorScheme = HXOBubbleColorSchemeWhite;
    i11.pointDirection = HXOMessageDirectionIncoming;
    i11.attachmentStyle = HXOAttachmentStyleThumbnail;
    i11.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_image"];
    i11.largeAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_image"];
    i11.previewImage = [UIImage imageNamed:@"cupcakes.jpg"];
    i11.attachmentText = @"cupcakes.jpg";

    BubbleItem * i12 = [[BubbleItem alloc] init];
    i12.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i12.colorScheme = HXOBubbleColorSchemeRed;
    i12.pointDirection = HXOMessageDirectionOutgoing;
    i12.attachmentStyle = HXOAttachmentStyleThumbnail;
    i12.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_music"];
    i12.largeAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_music"];
    i12.attachmentText = @"Cool Song";

    BubbleItem * i13 = [[BubbleItem alloc] init];
    i13.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i13.colorScheme = HXOBubbleColorSchemeWhite;
    i13.pointDirection = HXOMessageDirectionIncoming;
    i13.attachmentStyle = HXOAttachmentStyleThumbnail;
    i13.smallAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_s_location"];
    i13.largeAttachmentTypeIcon = [UIImage imageNamed:@"attachment_icon_location"];
    i13.attachmentText = @"Nice Place";
    i13.attachmentTransferState = HXOAttachmentTranserStateInProgress;

    BubbleItem * i14 = [[BubbleItem alloc] init];
    i14.cellIdentifier = [AttachmentMessageCell reuseIdentifier];
    i14.colorScheme = HXOBubbleColorSchemeWhite;
    i14.pointDirection = HXOMessageDirectionIncoming;
    i14.attachmentStyle = HXOAttachmentStyleOriginalAspect;
    CGSize imageSize = [UIImage imageNamed:@"cupcakes.jpg"].size;
    i14.imageAspect = imageSize.width / imageSize.height;
    i14.attachmentTransferState = HXOAttachmentTranserStateInProgress;
    i14.progress = 0.5;


    _items = @[i0, i1, i2, i3, i4, i5, i6, i7,
               i8, i9, i10, i11, i12, i13, i14];
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

- (void) chattyLabel:(HXOLinkyLabel *)label didTapToken:(NSTextCheckingResult *)match ofClass:(id)tokenClass {
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
    [self configureCell: cell item: item];
    return cell;
}

- (void) configureCell: (BubbleViewToo*) cell item: (BubbleItem*) item {
    if ([item.cellIdentifier isEqualToString: [TextMessageCell reuseIdentifier]]) {
        [self configureTextCell: (TextMessageCell*)cell item: item];
    } else if ([item.cellIdentifier isEqualToString: [AttachmentMessageCell reuseIdentifier]]) {
        [self configureAttachmentCell: (AttachmentMessageCell*)cell item: item];
    }
}

- (void) configureTextCell: (TextMessageCell*) cell item: (BubbleItem*) item {
    if (cell.label.tokenClasses.count == 0) {
        [self registerTokenClasses: cell.label];
        cell.label.delegate = self;
    }
    cell.label.text = item.text;
}

- (void) configureAttachmentCell: (AttachmentMessageCell*) cell item: (BubbleItem*) item {
    cell.previewImage = item.previewImage;
    cell.imageAspect = item.imageAspect;
    cell.attachmentStyle = item.attachmentStyle;
    cell.smallAttachmentTypeIcon = item.smallAttachmentTypeIcon;
    cell.largeAttachmentTypeIcon = item.largeAttachmentTypeIcon;
    cell.attachmentTransferState = item.attachmentTransferState;
    cell.progressBar.progress = item.progress;
    cell.runButtonStyle = item.runButtonStyle;

    NSString * title = item.attachmentText;
    NSMutableAttributedString * attributedTitle;
    NSString * fileExtension = [title pathExtension];
    if (title != nil) {
        if (item.attachmentTransferState == HXOAttachmentTranserStateInProgress) {
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
        self.colorScheme = HXOBubbleColorSchemeBlue;
    }
    return self;
}
@end

