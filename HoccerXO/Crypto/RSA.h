//
//  RSA.h
//  Hoccer
//
//  Created by Robert Palmer on 23.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// TODO: split this up: I have the feeling half of the key managment belongs to Contact,
//       the other half to UserProfile. En- and decryption don't need members and should
//       be class methods.

@interface RSA : NSObject {
    NSData *publicTag;
    NSData *privateTag;
    NSData *publicPeerTag;
}

+ (RSA*)sharedInstance;

- (void)generateKeyPairKeys;
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

-(void)cleanKeyPairKeys;
-(BOOL)cloneKeyPairKeys;

- (NSData *) publicTagForPeer:(NSString *) peerName;

+ (NSString*)makeSSHFormattedPublicKey:(NSData *)publicKeyBits;
+ (NSString*)makeX509FormattedPublicKey:(NSData *)publicKeyBits;
+ (NSData*)extractPublicKeyBitsFromPEM:(NSString *)pemPublicKeyString;

+ (NSString*)makePEMFormattedPrivateKey:(NSData *)privateKeyBits;
+ (NSData*)extractPrivateKeyBitsFromPEM:(NSString *)pemPrivateKeyString;


+ (int)getPublicKeySize:(NSData*)keyBits;

+ (NSData *) calcKeyId:(NSData *) myKeyBits;
+ (NSString *) keyIdString:(NSData *) myKeyId;

@end
