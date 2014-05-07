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
@property (strong) HXOHyperLabel      * instructions;
@property (strong) HXOHyperLabel      * expertNote;
@property (strong) UIPickerView       * sizePicker;

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

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(onDone:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"go", nil) style: UIBarButtonItemStyleDone target: self action: @selector(onDone:)];

    self.generateOrImportSelector = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"key_custom_generate_nav_title", nil), NSLocalizedString( @"key_custom_import_nav_title", nil)]];
    [self.generateOrImportSelector addTarget: self action: @selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
    self.navigationItem.titleView = self.generateOrImportSelector;

    self.instructions = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
    self.instructions.translatesAutoresizingMaskIntoConstraints = NO;
    self.instructions.attributedText = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"key_custom_size_instructions", nil)];
    self.instructions.font = [UIFont preferredFontForTextStyle: UIFontTextStyleBody];
    [self.view addSubview: self.instructions];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.instructions attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    self.sizePicker = [[UIPickerView alloc] initWithFrame: CGRectZero];
    self.sizePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.sizePicker.dataSource = self;
    self.sizePicker.delegate = self;
    [self.sizePicker selectRow: [self.validKeySizes indexOfObject: @(kHXODefaultKeySize)] inComponent: 0 animated: NO];
    [self.view addSubview: self.sizePicker];
    [self.view addConstraint: [NSLayoutConstraint constraintWithItem: self.sizePicker attribute: NSLayoutAttributeCenterX relatedBy: NSLayoutRelationEqual toItem: self.view attribute: NSLayoutAttributeCenterX multiplier: 1 constant: 0]];

    NSDictionary * views = @{@"instructions": self.instructions,
                             @"picker": self.sizePicker
                             };
    NSString * format = [NSString stringWithFormat: @"V:|-(>=%f)-[instructions]-%f-[picker]-%f-|", kHXOCellPadding, kHXOGridSpacing, kHXOCellPadding];
    [self.view addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
    self.generateOrImportSelector.selectedSegmentIndex = 0;
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

        }
    }
    [self dismissViewControllerAnimated: YES completion: nil];
}

- (void) segmentChanged: (id) sender {
    self.navigationItem.rightBarButtonItem.enabled = self.generateOrImportSelector.selectedSegmentIndex == 0;
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
    return self.view.bounds.size.width;
}

@end
