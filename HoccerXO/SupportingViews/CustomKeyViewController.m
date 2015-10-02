//
//  CustomKeyViewController.m
//  HoccerXO
//
//  Created by David Siegel on 06.05.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "CustomKeyViewController.h"

#import "ModalTaskHUD.h"
#import "UserProfile.h"
#import "HXOHyperLabel.h"
#import "HXOUI.h"
#import "AppDelegate.h"

@interface CustomKeyViewController ()

@property (strong) UISegmentedControl * generateOrImportSelector;
@property (strong) HXOHyperLabel      * generateInstructions;
@property (strong) HXOHyperLabel      * expertNote;
@property (strong) UIPickerView       * sizePicker;

@property (strong) UIView             * importView;
@property (strong) HXOHyperLabel      * importInstructions;
@property (strong) UITextView         * pemKeysTextView;

@property (strong) NSArray            * validKeySizes;

@end

@implementation CustomKeyViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.validKeySizes = @[@(1024), @(2048), @(3072), @(4096)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(onDone:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"go", nil) style: UIBarButtonItemStyleDone target: self action: @selector(onDone:)];

    self.generateOrImportSelector = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"key_custom_generate_nav_title", nil), NSLocalizedString( @"key_custom_import_nav_title", nil)]];
    [self.generateOrImportSelector addTarget: self action: @selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
    self.navigationItem.titleView = self.generateOrImportSelector;

    self.generateInstructions = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
    self.generateInstructions.translatesAutoresizingMaskIntoConstraints = NO;
    self.generateInstructions.attributedText = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"key_custom_size_instructions", nil)];
    self.generateInstructions.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    [self.view addSubview: self.generateInstructions];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.generateInstructions attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    self.sizePicker = [[UIPickerView alloc] initWithFrame: CGRectZero];
    self.sizePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.sizePicker.dataSource = self;
    self.sizePicker.delegate = self;
    [self.sizePicker selectRow: [self.validKeySizes indexOfObject: @(kHXODefaultKeySize)] inComponent: 0 animated: NO];
    [self.view addSubview: self.sizePicker];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.sizePicker attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    NSDictionary * views = @{@"instructions": self.generateInstructions,
                             @"picker": self.sizePicker
                             };
    NSString * format = [NSString stringWithFormat: @"V:|-(>=%f)-[instructions]-%f-[picker]-%f-|", kHXOCellPadding, kHXOGridSpacing, kHXOCellPadding];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
    self.generateOrImportSelector.selectedSegmentIndex = 0;

    self.importView = [[UIView alloc] initWithFrame: self.view.bounds];
    self.importView.backgroundColor = [UIColor whiteColor];
    self.importView.translatesAutoresizingMaskIntoConstraints = NO;
    self.importView.alpha = 0;
    self.importView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    [self.view addSubview: self.importView];

    self.importInstructions = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
    self.importInstructions.translatesAutoresizingMaskIntoConstraints = NO;
    self.importInstructions.attributedText = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"key_custom_import_instructions", nil)];
    self.importInstructions.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    [self.importView addSubview: self.importInstructions];


    views = @{@"v": self.importView};
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"H:|[v(>=0)]|" options: 0 metrics: nil views: views]];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: @"V:|[v(>=0)]|" options: 0 metrics: nil views: views]];

    self.pemKeysTextView = [self makeTextView];
    [self.importView addSubview: self.pemKeysTextView];

    views = @{@"inst": self.importInstructions,
              @"pubText":   self.pemKeysTextView
              };
    format = [NSString stringWithFormat: @"V:|-(%f)-[inst]-%f-[pubText]-%f-|", kHXOCellPadding, 3 * kHXOGridSpacing, kHXOCellPadding];
    [self.importView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    format = [NSString stringWithFormat: @"H:|-%f-[inst]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.importView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

    format = [NSString stringWithFormat: @"H:|-%f-[pubText]-%f-|", kHXOCellPadding, kHXOCellPadding];
    [self.importView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

}

- (UITextView*) makeTextView {
    UITextView * text = [[UITextView alloc] initWithFrame: CGRectZero];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.layer.cornerRadius = kHXOGridSpacing;
    text.layer.borderColor  = [HXOUI theme].messageFieldBorderColor.CGColor;
    text.layer.borderWidth  = 1;
    text.inputView = [[UIView alloc] initWithFrame: CGRectZero];
    text.delegate = self;
    return text;
}

- (BOOL) shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation) preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) onDone: (id) sender {
    if ([sender isEqual: self.navigationItem.rightBarButtonItem]) {
        if (self.generateOrImportSelector.selectedSegmentIndex == 0) {
            NSUInteger keySize = [self.validKeySizes[[self.sizePicker selectedRowInComponent: 0]] unsignedIntegerValue];
            [AppDelegate renewRSAKeyPairWithSize: keySize];
        } else {
            if ( ! [[UserProfile sharedProfile] importKeypair: self.pemKeysTextView.text]) {
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"key_import_failed_title", nil)
                                                                 message: NSLocalizedString(@"key_import_failed", nil)
                                                         completionBlock: ^(NSUInteger buttonIndex, UIAlertView* alertView) { }
                                                       cancelButtonTitle: NSLocalizedString(@"ok", nil)
                                                       otherButtonTitles: nil];
                [alert show];
            }
        }
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) segmentChanged: (UISegmentedControl*) segmentedControl {
    self.navigationItem.rightBarButtonItem.enabled = self.generateOrImportSelector.selectedSegmentIndex == 0;
    self.importView.alpha = segmentedControl.selectedSegmentIndex == 1 ? 1 : 0;
}

- (NSInteger)numberOfComponentsInPickerView: (UIPickerView*) pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.validKeySizes.count;
}

- (NSString*) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [NSString stringWithFormat: NSLocalizedString(@"key_length_unit_format", nil), self.validKeySizes[row]];
}

- (CGFloat) pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    return pickerView.bounds.size.width;
}

- (void) textViewDidChange:(UITextView *)textView {
    self.navigationItem.rightBarButtonItem.enabled =  ! [@"" isEqualToString: self.pemKeysTextView.text];
}

@end
