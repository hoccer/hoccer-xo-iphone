//
//  Message.h
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Contact;
@class Attachment;
@class Delivery;

#import "HXOModel.h"

@interface HXOMessage : HXOModel<UIActivityItemSource>

@property (nonatomic, strong) NSString* body;
@property (nonatomic, strong) NSDate*   timeSent; // estimated server time when message was sent, set by client and passed unchanged to receivers in message object
@property (nonatomic, strong) NSDate*   timeReceived; // estimated server time when message was received by client, set by client on reception, never passed
@property (nonatomic, strong) NSDate*   timeAccepted; // server time stamp when message was accepted by the Server, passed on via Delivery
@property (nonatomic, strong) NSNumber* isOutgoing;
@property (nonatomic, strong) NSDate* timeSection;
@property (nonatomic, strong) NSNumber* isRead;
@property (nonatomic, strong) NSString* messageId;
@property (nonatomic, strong) NSString* messageTag;
@property (nonatomic, strong) NSString* senderId;
@property (nonatomic, strong) NSString* attachmentFileId;
@property (nonatomic, strong) NSData* salt;
@property (nonatomic, strong) NSData* outgoingCryptoKey;
@property (nonatomic, strong) NSData* sourceMAC;
@property (nonatomic, strong) NSData* destinationMAC;
@property (nonatomic, strong) NSData* signature;
@property (nonatomic, strong) NSData* sharedKeyId;
@property (nonatomic, strong) NSData* sharedKeyIdSalt;

@property (nonatomic, strong) Contact*  contact;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) NSMutableSet * deliveries;

@property (nonatomic, strong) NSData * cryptoKey;

@property (nonatomic) NSString * bodyCiphertext;
@property (nonatomic, strong) NSString* saltString;
@property (nonatomic, strong) NSString* sourceMACString;
@property (nonatomic, strong) NSString* signatureString;
@property (nonatomic, strong) NSString* sharedKeyIdString;
@property (nonatomic, strong) NSString* sharedKeyIdSaltString;

@property (nonatomic) NSNumber *   timeSentMillis;
@property (nonatomic) NSNumber *   timeAcceptedMillis;

@property (nonatomic) CGFloat cachedPortraitCellHeight;
@property (nonatomic) CGFloat cachedLandscapeCellHeight;
@property (nonatomic) NSString * cachedBuildNumber;
@property (nonatomic) double cachedMessageFontSize;

@property (nonatomic) CGFloat cachedCellHeight;


- (void) setupOutgoingEncryption;
- (NSString *)encryptString: (NSString *)string;
- (NSString *)decryptString: (NSString *)string;
- (NSData *)encrypt:(NSData *)data;
- (NSData *)decrypt:(NSData *)data;

- (NSData*)computeHMAC;
- (void)sign;
- (BOOL)verifySignatureWithPublicKey:(SecKeyRef)publicKey;


@end
