//
//  HXOPeoplePickerViewController.m
//  HoccerXO
//
//  Created by David Siegel on 07.06.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "PeopleMultiPickerViewController.h"

#import <AddressBook/AddressBook.h>

#import "AppDelegate.h"

@interface PeopleMultiPickerViewController ()

@property (nonatomic, assign)   ABAddressBookRef   addressBook;
@property (nonatomic, strong)   NSArray          * peopleList;
@property (nonatomic, readonly) NSArray          * currentPeopleList;
@property (nonatomic, strong)   NSArray          * filteredPeopleList;
@property (nonatomic, strong)   NSMutableArray   * selectedPeople;
@property (nonatomic, strong)   NSMutableArray   * selectedProperties;
@property (nonatomic, strong)   NSMutableArray   * selectedPropertyMVI;

@end

@implementation PeopleMultiPickerViewController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
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
    self.selectedPeople = [NSMutableArray array];
    self.selectedProperties = [NSMutableArray array];
    self.selectedPropertyMVI = [NSMutableArray array];
    self.addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(cancel:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action: @selector(done:)];
}

- (void) dealloc {
    CFRelease(self.addressBook);
}

- (void)viewDidLoad {
    UISearchBar * searchBar = [[UISearchBar alloc] initWithFrame: CGRectMake(0, 0, self.tableView.bounds.size.width, 44)];
    searchBar.delegate = self;
    self.tableView.tableHeaderView = searchBar;
    self.tableView.contentOffset = CGPointMake(0, searchBar.bounds.size.height);

    [self.tableView registerClass: [UITableViewCell class] forCellReuseIdentifier: @"cell"];
    [self createPeopleList];

    [super viewDidLoad];
}

- (void) createPeopleList {
    typedef NSInteger compare(id, id, void*);

    NSArray * people = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(self.addressBook);
    self.peopleList = [people sortedArrayUsingFunction: (compare*)ABPersonComparePeopleByName context: (void*) ABPersonGetSortOrdering()];

    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentPeopleList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"cell" forIndexPath:indexPath];

    ABRecordRef person = (__bridge ABRecordRef)(self.currentPeopleList[indexPath.row]);

    [self configureCell: cell withPerson: person];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ABRecordRef person = (__bridge ABRecordRef)(self.currentPeopleList[indexPath.row]);

    NSUInteger index = [self.selectedPeople indexOfObject: (__bridge id)(person)];
    if (index == NSNotFound) {
        // XXX kind of duplicate with numberOfContactPoints
        NSArray * properties = [self pickableProperties];
        NSUInteger total = 0;
        ABPropertyID selectedProperty = 0;
        for (id property in properties) {
            ABMultiValueRef multiValue = ABRecordCopyValue(person, [property intValue]);
            NSUInteger count = ABMultiValueGetCount(multiValue);
            total += count;
            if (count == 1) {
                selectedProperty = [property intValue];
            }
            CFRelease(multiValue);
        }
        if (total == 1) {
            ABMultiValueRef multiValue = ABRecordCopyValue(person, selectedProperty);
            ABMultiValueIdentifier identifier = ABMultiValueGetIdentifierAtIndex(multiValue, 0);
            [self.selectedPeople addObject: (__bridge id)person];
            [self.selectedProperties addObject: @(selectedProperty)];
            [self.selectedPropertyMVI addObject: @(identifier)];
            CFRelease(multiValue);
            [self updateCellForPerson: person];
        } else {
            ABPersonViewController *view = [[ABPersonViewController alloc] init];
            view.personViewDelegate = self;
            view.displayedPerson = person;
            view.displayedProperties = properties;
            view.allowsActions = NO;

            [self.navigationController pushViewController:view animated:YES];
        }
    } else {
        [self.selectedPeople removeObjectAtIndex: index];
        [self.selectedProperties removeObjectAtIndex: index];
        [self.selectedPropertyMVI removeObjectAtIndex: index];
        [self updateCellForPerson: person];
    }
}

- (NSUInteger) numberOfContactPoints: (ABRecordRef) person {
    NSArray * properties = [self pickableProperties];
    NSUInteger total = 0;
    for (id property in properties) {
        ABMultiValueRef multiValue = ABRecordCopyValue(person, [property intValue]);
        NSUInteger count = ABMultiValueGetCount(multiValue);
        total += count;
        CFRelease(multiValue);
    }
    return total;
}


- (NSString *)name: (ABRecordRef) personRecordRef {
    return CFBridgingRelease(ABRecordCopyCompositeName(personRecordRef));
}


- (NSArray*) pickableProperties {
    return self.mode == PeoplePickerModeMail ? @[@(kABPersonEmailProperty)] : @[@(kABPersonPhoneProperty), @(kABPersonEmailProperty)];
}

- (BOOL) personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
    [self.selectedPeople addObject: (__bridge id)(person)];
    [self.selectedProperties addObject: @(property)];
    [self.selectedPropertyMVI addObject: @(identifier)];
    [self.navigationController popViewControllerAnimated: YES];
    [self updateCellForPerson: person];
    return NO;
}

- (void) updateCellForPerson: (ABRecordRef) person {
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: [self.currentPeopleList indexOfObject: (__bridge id)(person)] inSection: 0];
    [self.tableView beginUpdates];
    [self configureCell: [self.tableView cellForRowAtIndexPath: indexPath] withPerson: person];
    [self.tableView endUpdates];
}

- (void) configureCell: (UITableViewCell*) cell withPerson: (ABRecordRef) person {
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [self name: person];
    cell.textLabel.enabled = [self numberOfContactPoints: person] != 0;

    BOOL isSelected = [self.selectedPeople indexOfObject: (__bridge id)(person)] == NSNotFound;
    cell.accessoryType = isSelected ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
}

#pragma mark - Searching

- (NSArray*) currentPeopleList {
    return self.filteredPeopleList ? self.filteredPeopleList : self.peopleList;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText && ! [searchText isEqualToString: @""]) {
        NSPredicate * predicate = [NSPredicate predicateWithFormat:@"self CONTAINS[cd] %@", searchText];
        self.filteredPeopleList = [self.peopleList filteredArrayUsingPredicate: [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return [predicate evaluateWithObject: [self name: (__bridge ABRecordRef)(evaluatedObject)] substitutionVariables: bindings];
        }]];
    } else {
        self.filteredPeopleList = nil;
    }
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void) cancel: (id) sender {
    [self.delegate peopleMultiPickerDidCancel: self];
}

- (void) done: (id) sender {
    NSMutableArray * selection = [NSMutableArray array];
    for (int i = 0; i < self.selectedPeople.count; ++i) {
        [selection addObject: @{@"person"    : self.selectedPeople[i],
                                @"property"  : self.selectedProperties[i],
                                @"identifier": self.selectedPropertyMVI[i]
                                }];
    }
    [self.delegate peopleMultiPicker: self didFinishWithSelection: selection];
}

@end
