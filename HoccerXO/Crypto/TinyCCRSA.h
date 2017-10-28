//
//  TinyCCRSA.h
//  HoccerXO
//
//  Created by Pavel Mayer on 28.10.17.
//  Copyright © 2017 Hoccer GmbH. All rights reserved.
//

#ifndef TinyCCRSA_h
#define TinyCCRSA_h

#import <Foundation/Foundation.h>

@interface TinyCCRSA : NSObject {
    NSData *publicTag;
    NSData *privateTag;
    NSData *publicPeerTag;
}

+ (TinyCCRSA*)sharedInstance;

- (BOOL)hasKeyPair;
//- (BOOL)generateKeyPairKeysWithBits:(NSNumber *) bits;
- (BOOL)deleteKeyPairKeys;
- (BOOL)cloneKeyPairKeys;
- (BOOL)deleteAllRSAKeys;

- (void)testEncryption;
- (NSString *)generateRandomString:(NSUInteger)length;

- (SecKeyRef)getPrivateKeyRef;
- (NSData *)getPublicKeyBits;
- (SecKeyRef)getPublicKeyRef;
- (NSData *)getPrivateKeyBits;
- (SecKeyRef)getPrivateKeyRefForPublicKeyIdString:(NSString*) publicKeyIdString;
- (SecKeyRef)getPrivateKeyRefForPublicKeyId:(NSData*) publicKeyId;

- (BOOL)addPrivateKeyBits:(NSData*)privateKeyBits;
- (BOOL)addPrivateKeyBits:(NSData*)privateKeyBits withTag:(NSData*)privateTag;

- (BOOL)addPublicKeyBits:(NSData*)publiceKeyBits;
- (BOOL)addPublicKeyBits:(NSData *)d_key withTag:(NSData *)d_tag;
- (BOOL)addPublicKey:(NSString *)key withTag:(NSData *)tag;
- (BOOL)addPublicPeerKey:(NSString *)key withPeerName:(NSString *)peerName;

- (BOOL) importKeypairFromPEM: (NSString*) pemText;
- (BOOL) importKeypairFromPEM: (NSString*) pemText withPublicTag: (NSData*) tag;

- (BOOL)importPrivateKeyBits:(NSString *)pemPrivateKeyString;

// - (void)decryptWithPrivateKey:(uint8_t *)cipherBuffer plainBuffer:(uint8_t *)plainBuffer;
// - (void)encryptWithPublicKey:(uint8_t *)plainBuffer cipherBuffer:(uint8_t *)cipherBuffer;

- (NSData*)encryptWithKey:(SecKeyRef)key plainData:(NSData *)plainData;
- (NSData*)decryptWithKey:(SecKeyRef)key cipherData: (NSData *)cipherData;

- (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef;
- (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)keyRef;
- (void)removePeerPublicKey:(NSString *)peerName;
- (SecKeyRef)getPeerKeyRef:(NSString *)peerName;

- (NSData*)stripPublicKeyHeader:(NSData *)d_key;

- (NSData *)getKeyBitsForPeerRef:(NSString *)peerName;

- (void)getCertificate;

- (NSDictionary*) findKeyPairs;

- (NSData *) publicTagForPeer:(NSString *) peerName;

+ (NSString*)makeSSHFormattedPublicKey:(NSData *)publicKeyBits;
+ (NSString*)makeX509FormattedPublicKey:(NSData *)publicKeyBits;
+ (NSData*)extractPublicKeyBitsFromPEM:(NSString *)pemPublicKeyString;

+ (NSString*)makePEMFormattedPrivateKey:(NSData *)privateKeyBits;
+ (NSData*)extractPrivateKeyBitsFromPEM:(NSString *)pemPrivateKeyString;


+ (NSInteger)getPublicKeySize:(NSData*)keyBits;

+ (NSData *) calcKeyId:(NSData *) myKeyBits;
+ (NSString *) keyIdString:(NSData *) myKeyId;

+ (NSData *)makeSignatureOf:(NSData *)hash withPrivateKey:(SecKeyRef)privateKey;
+ (BOOL) verifySignature:(NSData *)signature forHash:(NSData *)hash withPublicKey:(SecKeyRef)publicKey;

@end


#endif /* TinyCCRSA_h */
