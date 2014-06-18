//
//  Delivery.m
//  HoccerXO
//
//  Created by David Siegel on 16.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Delivery.h"
#import "Contact.h"
#import "HXOMessage.h"
#import "NSData+Base64.h"
#import "CCRSA.h"

#import "NSData+HexString.h"
#import "NSData+CommonCrypto.h"
#import "HXOBackend.h" // for class crypto methods
#import "Group.h"
#import "Attachment.h"

NSString * const kDeliveryStateNew                          = @"new";
NSString * const kDeliveryStateDelivering                   = @"delivering";
NSString * const kDeliveryStateDeliveredPrivate             = @"deliveredPrivate";
NSString * const kDeliveryStateDeliveredPrivateAcknowledged = @"deliveredPrivateAcknowledged";
NSString * const kDeliveryStateDeliveredUnseen              = @"deliveredUnseen";
NSString * const kDeliveryStateDeliveredUnseenAcknowledged  = @"deliveredUnseenAcknowledged";
NSString * const kDeliveryStateDeliveredSeen                = @"deliveredSeen";
NSString * const kDeliveryStateDeliveredSeenAcknowledged    = @"deliveredSeenAcknowledged";
NSString * const kDeliveryStateFailed                       = @"failed";
NSString * const kDeliveryStateRejected                     = @"rejected";
NSString * const kDeliveryStateAborted                      = @"aborted";
NSString * const kDeliveryStateAbortedAcknowledged          = @"aborteddelivered";
NSString * const kDeliveryStateFailedAcknowledged           = @"failedAcknowledged";
NSString * const kDeliveryStateRejectedAcknowledged         = @"rejectedAcknowledged";


NSString * const kDelivery_ATTACHMENT_STATE_NONE                            = @"none";
NSString * const kDelivery_ATTACHMENT_STATE_NEW                             = @"new";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOADING                       = @"uploading";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_PAUSED                   = @"paused";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOADED                        = @"uploaded";
NSString * const kDelivery_ATTACHMENT_STATE_RECEIVED                        = @"received";
NSString * const kDelivery_ATTACHMENT_STATE_RECEIVED_ACKNOWLEDGED           = @"receivedAcknowledged";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED                   = @"uploadFailed";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED_ACKNOWLEDGED      = @"uploadFailedAcknowledged";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED                  = @"uploadAborted";
NSString * const kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED_ACKNOWLEDGED     = @"uploadAbortedAcknowledged";
NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED                 = @"downloadFailed";
NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED_ACKNOWLEDGED    = @"downloadFailedAcknowledged";
NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED                = @"downloadAborted";
NSString * const kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED_ACKNOWLEDGED   = @"downloadAbortedAcknowledged";

@implementation Delivery

@dynamic state;
@dynamic message;
@dynamic receiver;
@dynamic sender;
@dynamic group;
@dynamic keyCiphertext;
@dynamic keyCiphertextString;
@dynamic keyCleartext;
@dynamic receiverKeyId;
@dynamic timeChanged;
@dynamic timeChangedMillis;
@dynamic keyId;
@dynamic attachmentState;

-(BOOL)isGroupDelivery {
    return self.group != nil && self.receiver == nil;
}


-(BOOL)isStateFailed {
    return [kDeliveryStateFailed isEqualToString:self.state] || [kDeliveryStateFailedAcknowledged isEqualToString:self.state];
}

-(BOOL)isInFinalState {
    return [Delivery isAcknowledgedState:self.state] && [Delivery isAcknowledgedAttachmentState:self.attachmentState];
}

-(BOOL)isDelivered {
    return [Delivery isDeliveredState:self.state] || [@"confirmed" isEqualToString:self.state]; // confirmed is to handle locally stored legacy state
}

-(BOOL)isSeen {
    return [Delivery isSeenState:self.state];
}

-(BOOL)isUnseen {
    return [Delivery isUnseenState:self.state];
}

-(BOOL)isPrivate {
    return [Delivery isPrivateState:self.state];
}

-(BOOL)isStateDelivering {
    return [kDeliveryStateDelivering isEqualToString:self.state];
}

-(BOOL)isStateNew {
    return [kDeliveryStateNew isEqualToString:self.state];
}

-(BOOL)isFailure {
    return [Delivery isFailureState:self.state];
}

-(BOOL)isPending {
    return [Delivery isPendingState:self.state];
}

-(BOOL)isAttachmentReceived {
    return [Delivery isAttachmentReceivedState:self.attachmentState];
}

-(BOOL)isAttachmentFailure {
    return [Delivery isAttachmentFailureState:self.attachmentState];
}

-(BOOL)isAttachmentPending {
    return [Delivery isAttachmentPendingState:self.attachmentState];
}



// attachment is not yet received
-(BOOL)isMissingAttachment {
    return ![kDelivery_ATTACHMENT_STATE_NONE isEqualToString:self.attachmentState] && !self.isAttachmentReceived;
}

-(BOOL)attachmentDownloadable {
    return self.message.attachment != nil &&
    self.message.attachment.downloadable &&
    ([kDelivery_ATTACHMENT_STATE_UPLOADING isEqualToString:self.attachmentState] ||
     [kDelivery_ATTACHMENT_STATE_UPLOADED isEqualToString:self.attachmentState]);
}

-(BOOL)attachmentUploadable {
    return self.message.attachment != nil &&
    self.message.attachment.uploadable &&
    !self.isFailure &&
    (self.isDelivered || self.isStateDelivering);
}


+(BOOL)isDeliveredState:(NSString*) state {
    return
    [kDeliveryStateDeliveredSeen isEqualToString:state] ||
    [kDeliveryStateDeliveredSeenAcknowledged isEqualToString:state] ||
    [kDeliveryStateDeliveredUnseen isEqualToString:state] ||
    [kDeliveryStateDeliveredUnseenAcknowledged isEqualToString:state] ||
    [kDeliveryStateDeliveredPrivate isEqualToString:state] ||
    [kDeliveryStateDeliveredPrivateAcknowledged isEqualToString:state];
}

+(BOOL)isFailureState:(NSString*) state {
    return [kDeliveryStateFailed isEqualToString:state] ||
    [kDeliveryStateFailedAcknowledged isEqualToString:state] ||
    [kDeliveryStateRejected isEqualToString:state] ||
    [kDeliveryStateRejectedAcknowledged isEqualToString:state] ||
    [kDeliveryStateAborted isEqualToString:state] ||
    [kDeliveryStateAbortedAcknowledged isEqualToString:state];
}


+(BOOL)isAcknowledgedState:(NSString*) state {
    return [kDeliveryStateDeliveredSeenAcknowledged isEqualToString:state] ||
    [kDeliveryStateDeliveredUnseenAcknowledged isEqualToString:state] ||
    [kDeliveryStateDeliveredPrivateAcknowledged isEqualToString:state] ||
    [kDeliveryStateAbortedAcknowledged isEqualToString:state] ||
    [kDeliveryStateRejectedAcknowledged isEqualToString:state] ||
    [kDeliveryStateFailedAcknowledged isEqualToString:state];
}

+(BOOL)isPendingState:(NSString*) state {
    return [kDeliveryStateNew isEqualToString:state] ||
    [kDeliveryStateDelivering isEqualToString:state];
}

+(BOOL)isSeenState:(NSString*) state {
    return [kDeliveryStateDeliveredSeen isEqualToString:state] ||
    [kDeliveryStateDeliveredSeenAcknowledged isEqualToString:state];
}

+(BOOL)isUnseenState:(NSString*) state {
    return [kDeliveryStateDeliveredUnseen isEqualToString:state] ||
    [kDeliveryStateDeliveredUnseenAcknowledged isEqualToString:state];
}

+(BOOL)isPrivateState:(NSString*) state {
    return [kDeliveryStateDeliveredPrivate isEqualToString:state] ||
    [kDeliveryStateDeliveredPrivateAcknowledged isEqualToString:state];
}

+(BOOL)shouldAcknowledgeStateForOutgoing:(NSString*) state {
    return [kDeliveryStateDeliveredSeen isEqualToString:state] ||
    [kDeliveryStateDeliveredUnseen isEqualToString:state] ||
    [kDeliveryStateDeliveredPrivate isEqualToString:state] ||
    [kDeliveryStateAborted isEqualToString:state] ||
    [kDeliveryStateRejected isEqualToString:state] ||
    [kDeliveryStateFailed isEqualToString:state];
}

+(BOOL)isAttachmentReceivedState:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_RECEIVED_ACKNOWLEDGED isEqualToString:attachmentState];
}

+(BOOL)isAttachmentPendingState:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_NEW isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOADING isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOADED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOAD_PAUSED isEqualToString:attachmentState];
}


+(BOOL)isAttachmentFailureState:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED_ACKNOWLEDGED isEqualToString:attachmentState];
}

+(BOOL)isAcknowledgedAttachmentState:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_NONE isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_RECEIVED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED_ACKNOWLEDGED isEqualToString:attachmentState];
}

+(BOOL)shouldAcknowledgeAttachmentStateForOutgoing:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_RECEIVED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_FAILED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_DOWNLOAD_ABORTED isEqualToString:attachmentState];
}

+(BOOL)shouldAcknowledgeAttachmentStateForIncoming:(NSString*) attachmentState {
    return [kDelivery_ATTACHMENT_STATE_UPLOAD_FAILED_ACKNOWLEDGED isEqualToString:attachmentState] ||
    [kDelivery_ATTACHMENT_STATE_UPLOAD_ABORTED_ACKNOWLEDGED isEqualToString:attachmentState];
}


-(NSString*) keyCiphertextString {
    return [self.keyCiphertext asBase64EncodedString];
}

-(void) setKeyCiphertextString:(NSString*) theB64String {
    // NSLog(@"Delivery: setKeyCiphertextString: ‘%@‘", theB64String);
    if ([theB64String isKindOfClass:[NSString class]]) {
        self.keyCiphertext = [NSData dataWithBase64EncodedString:theB64String];
        // NSLog(@"Delivery: setKeyCiphertext = : ‘%@‘",  self.keyCiphertext);
    } else {
        NSLog(@"Delivery: setKeyCiphertextString: nil key in message");
    }
}

-(NSString*) receiverKeyId {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        // for outgoing deliveries
        if ([self.message.contact.type isEqualToString:@"Group"]) {
            self.keyId = @"0000000000000000";  // sent arbitrary string, will be substituted by server
        } else {
            self.keyId = self.receiver.publicKeyId;
        }
        return self.keyId;
    } else {
        // for incoming deliveries
        return self.keyId;
    }
}

// for incoming deliveries
-(void) setReceiverKeyId:(NSString *) theKeyId {
    self.keyId = theKeyId;
}


// this function will yield the plaintext the keyCiphertext by decrypting it with the private key
- (NSData *) keyCleartext {
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        return nil; // can not decrypt outgoing key
    }
    CCRSA * rsa = [CCRSA sharedInstance];
    SecKeyRef myPrivateKeyRef = [rsa getPrivateKeyRefForPublicKeyIdString:self.receiverKeyId];
    if (myPrivateKeyRef == NULL) {
        NSLog(@"ERROR: I have no private key for key id %@", self.receiverKeyId);
        return nil;
    }
    NSData * theClearTextKey = [rsa decryptWithKey:myPrivateKeyRef cipherData:self.keyCiphertext];
    return theClearTextKey;
}

// this function will set the the keyCiphertext by encrypting the theMessageKey with the public key of the receiver
- (void) setKeyCleartext:(NSData *) theMessageKey {
    self.keyCiphertext = nil;
    // check a lot of preconditions just in case...
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
        return;
    }
    if (![self.state isEqualToString:kDeliveryStateNew]) {
        return;
    }
    if (self.receiver == nil) {
        return;
    }
    if (theMessageKey == nil) {
        return;
    }
    
    // get public key of receiver first
    SecKeyRef myReceiverKey = [self.receiver getPublicKeyRef];

    // Since we support custom key sizes it is very well possible to end up without a public key.
    // Because we might have more than one delivery and this is called in a setter in a setter ... in a setter
    // we tag the delivery as failed here. The backend respects this by not sending the message. [DS]
    if ( ! myReceiverKey) {
        self.state = kDeliveryStateFailed;
        return;
    }
    
    CCRSA * rsa = [CCRSA sharedInstance];
    self.keyCiphertext = [rsa encryptWithKey:myReceiverKey plainData:theMessageKey];
}


- (BOOL) setupKeyCiphertext {
    self.keyCleartext = self.message.cryptoKey;
    if (self.keyCiphertext != nil) {
        return YES;
    }
    return NO;
}


- (NSNumber*) timeChangedMillis {
    return [HXOBackend millisFromDate:self.timeChanged];
}

- (void) setTimeChangedMillis:(NSNumber*) milliSecondsSince1970 {
    self.timeChanged = [HXOBackend dateFromMillis:milliSecondsSince1970];
}


- (NSDictionary*) rpcKeys {
    return @{ @"state"         : @"state",
//              @"receiverId"    : @"receiver.clientId",
//              @"groupId"       : @"group.clientId",
//              @"senderId"      : @"sender.clientId",
              @"messageTag"    : @"message.messageTag",
              @"messageId"     : @"message.messageId",
              @"timeAccepted"  : @"message.timeAcceptedMillis",
              @"timeChanged"   : @"timeChangedMillis",
              @"keyId"         : @"receiverKeyId",
              @"keyCiphertext" : @"keyCiphertextString",
              @"attachmentState" : @"attachmentState"
              };
}

@end
