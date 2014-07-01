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

@property (nonatomic, assign) ABAddressBookRef   addressBook;
@property (nonatomic, strong) NSArray          * peopleList;
@property (nonatomic, strong) NSMutableArray   * selectedPeople;
@property (nonatomic, strong) NSMutableArray   * selectedProperties;
@property (nonatomic, strong) NSMutableArray   * selectedPropertyMVI;

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
    [self.tableView registerClass: [UITableViewCell class] forCellReuseIdentifier: @"cell"];
    [self createPeopleList];

    [super viewDidLoad];
}

- (void) createPeopleList {
    self.peopleList = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(self.addressBook);
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
    return self.peopleList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"cell" forIndexPath:indexPath];

    ABRecordRef person = (__bridge ABRecordRef)(self.peopleList[indexPath.row]);

    [self configureCell: cell withPerson: person];
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    ABRecordRef person = (__bridge ABRecordRef)(self.peopleList[indexPath.row]);

    NSUInteger index = [self.selectedPeople indexOfObject: (__bridge id)(person)];
    if (index == NSNotFound) {
        ABPersonViewController *view = [[ABPersonViewController alloc] init];

        view.personViewDelegate = self;
        view.displayedPerson = person; //CFBridgingRetain(person);
        view.displayedProperties = @[@(kABPersonPhoneProperty), @(kABPersonEmailProperty)];
        view.allowsActions = NO;

        [self.navigationController pushViewController:view animated:YES];
    } else {
        [self.selectedPeople removeObjectAtIndex: index];
        [self.selectedProperties removeObjectAtIndex: index];
        [self.selectedPropertyMVI removeObjectAtIndex: index];
        [self updateCellForPerson: person];
    }

}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString: @"showPerson"]) {
        ABPersonViewController * vc = (ABPersonViewController*)segue.destinationViewController;
        vc.displayedPerson = CFBridgingRetain((self.peopleList[((NSIndexPath*)sender).row]));
        vc.personViewDelegate = self;
    }
}

- (NSString *)name: (ABRecordRef) personRecordRef {
	NSString *firstName = CFBridgingRelease(ABRecordCopyValue(personRecordRef, kABPersonFirstNameProperty));
	NSString *lastName = CFBridgingRelease(ABRecordCopyValue(personRecordRef, kABPersonLastNameProperty));

	if (lastName == NULL && firstName == NULL) {
		return nil;
	}

	if (lastName != NULL && firstName == NULL) {
		return lastName;
	}

	if (lastName == NULL && firstName != NULL) {
		return firstName;
	}

	return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
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
    NSIndexPath * indexPath = [NSIndexPath indexPathForItem: [self.peopleList indexOfObject: (__bridge id)(person)] inSection: 0];
    [self.tableView beginUpdates];
    [self configureCell: [self.tableView cellForRowAtIndexPath: indexPath] withPerson: person];
    [self.tableView endUpdates];
}

- (void) configureCell: (UITableViewCell*) cell withPerson: (ABRecordRef) person {
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [self name: person];

    BOOL isSelected = [self.selectedPeople indexOfObject: (__bridge id)(person)] == NSNotFound;
    cell.accessoryType = isSelected ? UITableViewCellAccessoryNone : UITableViewCellAccessoryCheckmark;
    cell.detailTextLabel.text = [self selectedPropertyValueForPerson: person];
}

- (NSString*) selectedPropertyValueForPerson: (ABRecordRef) person {
    NSUInteger index = [self.selectedPeople indexOfObject: (__bridge id)(person)];
    if (index != NSNotFound) {
        ABPropertyID property = [self.selectedProperties[index] integerValue];
        ABMultiValueIdentifier identifier = [self.selectedPropertyMVI[index] integerValue];
        ABMultiValueRef = ABRecordCopyValue( person,  property);


    }
    return nil;
}

#pragma mark - Actions

- (void) cancel: (id) sender {
    [self dismissViewControllerAnimated: YES completion: nil];

}

- (void) done: (id) sender {
    AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    UIViewController * vc = self.mode == PeoplePickerModeMail ? appDelegate.mailPicker : appDelegate.smsPicker;
    [self.navigationController pushViewController: vc animated: YES];
}

@end
