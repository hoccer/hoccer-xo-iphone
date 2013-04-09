//
//  FirstRunViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 27.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "FirstRunViewController.h"

#import "InsetImageView.h"
#import "AppDelegate.h"
#import "Contact.h"
#import "TalkMessage.h"
#import "NSString+UUID.h"
#import "Attachment.h"
#import "AppDelegate.h"
#import "HTUserDefaults.h"
#import "Relationship.h"

@implementation FirstRunViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    identities = @[@"Azrael", @"Schlumpfine", @"Daddy S", @"Gargamel", @"Mr. Mister", ];
    avatars = @[ @"azrael", @"schlumpf_schlumpfine", @"schlumpf_papa", @"gargamel"];

    identityPicker = [self pickerInputViewForTextField: identityTextField];

    identityTextField.text = identities[0];
    avatarView.image = [UIImage imageNamed: avatars[0]];


    messageCounts = [[NSMutableArray alloc] init];
    [messageCounts addObject: [@1 stringValue]];
    [messageCounts addObject: [@5 stringValue]];
    [messageCounts addObject: [@10 stringValue]];
    [messageCounts addObject: [@50 stringValue]];
    [messageCounts addObject: [@100 stringValue]];
    for (int i = 500; i <= 10000; i += 500) {
        [messageCounts addObject: [[NSNumber numberWithInt: i] stringValue]];
    }

    messageCountPicker = [self pickerInputViewForTextField: messageCountTextField];
    messageCountTextField.text = messageCounts[0];
}

-(void)pickerDoneClicked {
    [identityTextField resignFirstResponder];
    [messageCountTextField resignFirstResponder];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if ([pickerView isEqual: identityPicker]) {
        return identities.count;
    } else if ([pickerView isEqual: messageCountPicker]) {
        return messageCounts.count;
    }
    return 0;
}


- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if ([pickerView isEqual: identityPicker]) {
        return identities[row];
    } else if ([pickerView isEqual: messageCountPicker]) {
        return messageCounts[row];
    }
    return @"Kaputt";
}


- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if ([pickerView isEqual: identityPicker]) {
        identityTextField.text = (NSString *)identities[row];
        if (row < avatars.count) {
            avatarView.image = [UIImage imageNamed: avatars[row]];
        } else {
            avatarView.image = [UIImage imageNamed: @"avatar_default_contact"];
        }
    } else if ([pickerView isEqual: messageCountPicker]) {
        messageCountTextField.text = (NSString *)messageCounts[row];
    }
}

- (IBAction) donePressed: (id) sender {
    [self dismissModalViewControllerAnimated: YES];
    [self saveDummyProfile];
    [self addDummies];
    [[HTUserDefaults standardUserDefaults] setBool: YES forKey: kHTFirstRunDone];
    AppDelegate * appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    [appDelegate setupDone];
}

- (UIPickerView*) pickerInputViewForTextField: (UITextField*) textField {
    UIPickerView * picker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    picker.delegate = self;
    picker.dataSource = self;
    [picker setShowsSelectionIndicator:YES];

    textField.inputView =  picker;

    UIToolbar*  pickerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 56)];
    pickerToolbar.barStyle = UIBarStyleBlackOpaque;
    [pickerToolbar sizeToFit];
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(pickerDoneClicked)];
    NSArray *barItems = @[flexSpace, doneBtn];
    [pickerToolbar setItems:barItems animated:YES];
    textField.inputAccessoryView = pickerToolbar;
    return picker;
}

- (void) saveDummyProfile {
    [[HTUserDefaults standardUserDefaults] setObject: identityTextField.text forKey: kHTClientId];
    [[HTUserDefaults standardUserDefaults] setObject: identityTextField.text forKey: kHTNickName];
    [[HTUserDefaults standardUserDefaults] setObject: UIImagePNGRepresentation(avatarView.image) forKey: kHTAvatarImage];
    [[HTUserDefaults standardUserDefaults] synchronize];
}

- (void) addDummies {
    NSArray * messages = @[ @[ @"Miau..."
                             , @"*schnurrr*"
                             , @"Mauz..."
                             , @"*fauch*"
                             , @"flup flup"
                             ]
                            , @[ @"Käffchen?"
                               , @"k, bin in 10min da..."
                               , @"bis gloich"
                               , @"Was geht heute abend?"
                               , @"bin schon verabredet. Aber wir könnten am WE einen trinken gehen. In der Panke ist irgendwie HipHop party... Backyard Joints. Lorem ipsum blah fasel blub..."
                               , @"Mein Router ist abgeraucht :-/. Kannst Du ein ordentliches DSL Modem empfehlen?"
                               , @"Ich würde mal bei den Fritzboxen von AVM gucken. Das ist echt ordentliche Hardware."
                               , @"Check mal deine mail..."
                               , @"kewl! Will ich haben."
                               ]
                            , @[ @"Hast Du deine Hausaufgaben gemacht?"
                                 , @"Ja, Papa Schlumpf..."
                                 , @"und wasch Dir vor dem essen die Hände"
                                 , @"Ja, Papa Schlumpf..."
                                 , @"und geh nicht wieder so spät ins Bett"
                                 , @"Ja, Papa Schlumpf..."
                                 , @"Sei Sonnatg bitte pünktlich. Wir essen zeitig."
                                 , @"Ja, Papa Schlumpf..."
                                 ]
                            , @[ @"Ich HASSE Schlümpfe"
                                 , @"Aha."
                                 , @"Ich HASSE sie."
                                 , @"Ja, schon verstanden."
                                 , @"Ich HASSE sie!"
                                 , @"Iss ja gut jetzt."
                                 ]
                            , @[ @"Hallo?"
                                 , @"Ja... ?"
                                 , @"Öm..."
                                 , @"Ja... ?"
                                 , @"Bist Du der der ich glaube der Du bist?"
                                 , @"Öh..."
                                 ]
                            ];

    int messageCount = [messageCountTextField.text intValue];

    AppDelegate * appDelegate = ((AppDelegate *)[[UIApplication sharedApplication] delegate]);
    NSManagedObjectContext *importContext = appDelegate.managedObjectContext;

    int contactIndex = 0;
    for (NSString* nick in identities) {
        if ( ! [nick isEqualToString: identityTextField.text]) {
            NSLog(@"adding dummy conversation with %@", identities[contactIndex]);

            Contact * contact =  (Contact*)[NSEntityDescription insertNewObjectForEntityForName: [Contact entityName] inManagedObjectContext: importContext];
            contact.nickName = identities[contactIndex];
            if (contactIndex < [avatars count]) {
                contact.avatar = UIImagePNGRepresentation([UIImage imageNamed: avatars[contactIndex]]);
            }
            contact.clientId = identities[contactIndex];

            Relationship * relationship =  (Relationship*)[NSEntityDescription insertNewObjectForEntityForName: [Relationship entityName] inManagedObjectContext: importContext];
            relationship.state = kRelationStateNone;
            relationship.lastChanged = [NSDate dateWithTimeIntervalSince1970: 0];
            contact.relationship = relationship;

            NSDate *date = [NSDate dateWithTimeIntervalSinceNow: - (60*60*24*30)];
            contact.latestMessageTime = date;

            for(int i = 0; i < messageCount; ++i) {
                TalkMessage * message =  (TalkMessage*)[NSEntityDescription insertNewObjectForEntityForName: [TalkMessage entityName] inManagedObjectContext: importContext];

                message.body = messages[contactIndex][i % ((NSArray*)messages[contactIndex]).count];
                message.timeStamp = date;
                message.contact = contact;
                message.isOutgoing = i % 2 == 0 ? @NO : @YES;
                message.isRead = @NO;
                message.messageId = [NSString stringWithUUID];
                message.messageTag = [NSString stringWithUUID];

                message.timeSection = [contact sectionTitleForMessageTime: date];
                contact.latestMessageTime = date;

                if (rand() % 10 == 0) {
                    [self attachAttachment: message moc: importContext];
                }

                // TODO: add dummy delivery object

                int interval = rand() % (int)(2.5 * 60);
                date = [NSDate dateWithTimeInterval: interval sinceDate: date];
            }
        }
        contactIndex += 1;
    }
    NSError * error = nil;
    [importContext save:&error];
    if (error != nil) {
        NSLog(@"ERROR - failed to save message: %@", error);
        abort();
    }

}

- (void) attachAttachment: (TalkMessage*) message moc: (NSManagedObjectContext*) moc {

    NSString * path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"angry_wet_coala.jpg"];
    UIImage * image = [UIImage imageNamed: @"angry_wet_coala.jpg"];

    Attachment * attachment =  (Attachment*)[NSEntityDescription insertNewObjectForEntityForName: [Attachment entityName] inManagedObjectContext: moc];
    [attachment makeImageAttachment:[[NSURL fileURLWithPath: path] absoluteString] image: image];
        
    message.attachment = attachment;
}

@end
