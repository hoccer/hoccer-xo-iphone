//
//  Vcard.h
//  HoccerXO
//
//  Created by Pavel on 02.05.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

#import "ABPersonCreator.h"


@interface VcardPreview : UIView {
}

@property (strong) IBOutlet UILabel *name;
@property (strong) IBOutlet UILabel *company;
@property (strong) IBOutlet UILabel *otherInfo;
@property (strong) IBOutlet UIImageView *personImage;

@end


@interface Vcard : NSObject {
}

@property (readonly) ABRecordRef person;

@property (strong) IBOutlet VcardPreview *view;

- (id) initWithVcardString: (NSString *)vcard;
- (id) initWithVcardURL: (NSURL *)vcard;

// vcard fields
- (NSString *)nameString;
- (NSString *)organization;
- (NSString *)previewName;
- (NSString *)stringPropertyWithId: (ABPropertyID) propertyId;

// preview
- (UIImage *) previewImage;
- (UIImage *) previewImageWithScale:(CGFloat) myScale;
- (UIView *) preview;

// If scale is 0, iscreen scale is used to create the bounds
+ (UIImage *)imageFromView:(UIView*)view withScale:(CGFloat)scale;
@end
