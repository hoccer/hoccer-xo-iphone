
//
//  RSA.m
//  Hoccer
//
//  Created by Robert Palmer on 23.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//
//

#import "CCRSA.h"
#import "NSData+Base64.h"
#import "NSData+HexString.h"
#import "NSString+RandomString.h"
#import "NSData+CommonCrypto.h"

#import "HXOUserDefaults.h"

#import "OpenSSLCrypto.h"

#define RSA_DEBUG NO

@implementation CCRSA

static const uint32_t PADDING = kSecPaddingPKCS1;

static const uint8_t publicKeyIdentifier[]  = "com.hoccertalk.client.publickey";
static const uint8_t privateKeyIdentifier[] = "com.hoccertalk.client.privatekey";
static const uint8_t publicPeerKeyIdentifier[]  = "com.hoccertalk.peer.publickey";

static CCRSA *instance;

static NSObject * instanceLock;

+ (CCRSA*)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CCRSA alloc] init];
    });
    return instance;
}

- (id) init {
    self = [super init];
    if (self) {
        instanceLock = [NSObject new];
        privateTag = [[NSData alloc] initWithBytes:privateKeyIdentifier length:sizeof(privateKeyIdentifier)];
        publicTag = [[NSData alloc] initWithBytes:publicKeyIdentifier length:sizeof(publicKeyIdentifier)];
        publicPeerTag = [[NSData alloc] initWithBytes:publicPeerKeyIdentifier length:sizeof(publicPeerKeyIdentifier)];
    }
    
    return self;
}

- (NSString *)generateRandomString:(NSUInteger)length {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!§$%&/()=?";
    return [NSString stringWithRandomCharactersOfLength: length usingCharacterSet: letters];
}

- (BOOL)hasKeyPair {
    @synchronized(instanceLock) {
        return [instance getPublicKeyRef] != nil && [instance getPrivateKeyRef] != nil;
    }
}

-(BOOL)generateKeyPairKeysWithOpenSSLandSize:(int)bits {
    @synchronized(instanceLock) {
        NSString * pubkey;
        NSString * privkey;
        if ([OpenSSLCrypto makeRSAKeyPairPEMWithSize:bits withPublicKey:&pubkey withPrivateKey:&privkey]) {
            
            NSData * pubBits = [CCRSA extractPublicKeyBitsFromPEM:pubkey];
            NSData * privBits = [CCRSA extractPrivateKeyBitsFromPEM:privkey];
            
            if (privBits != nil && pubBits != nil) {
                [self deleteKeyPairKeys];
                BOOL ok1 = [self addPrivateKeyBits:privBits];
                BOOL ok2 = [self addPublicKeyBits:pubBits];
                return ok1 && ok2;
            }
        }
        return NO;
    }
}

- (BOOL)generateKeyPairKeysWithBits:(NSNumber *) bits {
    NSLog(@"Generating RSA Keys with %@ bits", bits);
    return [self generateKeyPairKeysWithOpenSSLandSize:[bits intValue]];
}

- (void)testEncryption {
    NSString *plainText = @"This is just a string";
    NSData *plainData = [plainText dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *cipher = [self encryptWithKey:[self getPublicKeyRef] plainData:plainData];
    
    NSData *decryptedData = [self decryptWithKey:[self getPrivateKeyRef] cipherData:cipher];
    NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    
    NSLog(@"decrypted %@", decryptedString);
}


- (NSData *)encryptWithKey:(SecKeyRef)key plainData:(NSData *)plainData {
    @synchronized(instanceLock) {
        OSStatus status = noErr;
        
        size_t cipherBufferSize = 0;
        size_t dataBufferSize    = 0;
        
        NSData *cipher = nil;
        uint8_t *cipherBuffer = nil;
        
        cipherBufferSize = SecKeyGetBlockSize(key);
        dataBufferSize = [plainData length];
        
        cipherBuffer = malloc(cipherBufferSize * sizeof(uint8_t));
        memset((void *)cipherBuffer, 0x0, cipherBufferSize);
        
        status = SecKeyEncrypt( key,
                               PADDING,
                               (const uint8_t *)[plainData bytes],
                               dataBufferSize,
                               cipherBuffer,
                               &cipherBufferSize);
        
        if (status != noErr) {
            NSLog(@"RSA:encryptWithKey: Error encrypting, OSStatus = %d", (NSInteger)status);
        }
        
        cipher = [NSData dataWithBytes:(const void *)cipherBuffer length:(NSUInteger)cipherBufferSize];
        if (cipherBuffer) { free(cipherBuffer); }
        
        return cipher;
    }
}

- (NSData *)decryptWithKey: (SecKeyRef)key cipherData: (NSData *)cipherData {
    @synchronized(instanceLock) {
        OSStatus status = noErr;
        size_t cipherBufferSize = 0;
        size_t plainBufferSize  = 0;
        
        NSData *plainData       = nil;
        uint8_t * plainBuffer   = NULL;
        
        cipherBufferSize = SecKeyGetBlockSize(key);
        
        plainBufferSize  = [cipherData length];
        plainBuffer = malloc(plainBufferSize * sizeof(uint8_t));
        memset((void *)plainBuffer, 0x0, plainBufferSize);
        
        status = SecKeyDecrypt(key,
                               PADDING,
                               (const uint8_t *)[cipherData bytes],
                               cipherBufferSize,
                               plainBuffer,
                               &plainBufferSize);
        
        if (status != noErr) {
            NSLog(@"CCRSA:decryptWithKey: Error decrypting, OSStatus = %d", (NSInteger)status);
            NSNotification *notification = [NSNotification notificationWithName:@"decryptionError" object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
            if (RSA_DEBUG) NSLog(@"%@", [NSThread callStackSymbols]);
        }
        
        //NSLog(@"decoded %d bytes, status %d", (NSInteger)plainBufferSize, (NSInteger)status);
        plainData = [NSData dataWithBytes:plainBuffer length:plainBufferSize];
        
        if (plainBuffer) { free(plainBuffer); }
        return plainData;
    }
}

- (SecKeyRef)getPublicKeyRef {
    @synchronized(instanceLock) {
        OSStatus resultCode = noErr;
        SecKeyRef publicKeyReference = NULL;
        
        NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
        
        // Set the public key query dictionary.
        [queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [queryPublicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPublicKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        
        // Get the key.
        resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyReference);
        
        if(resultCode != noErr)
        {
            publicKeyReference = NULL;
        }
        
        return publicKeyReference;
    }
}

- (void)getCertificate {
    @synchronized(instanceLock) {
        OSStatus resultCode = noErr;
        SecCertificateRef publicKeyCeritificate = NULL;
        
        NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
        
        // Set the public key query dictionary.
        [queryPublicKey setObject:(__bridge id)kSecClassCertificate forKey:(__bridge id)kSecClass];
        [queryPublicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPublicKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        
        // Get the key.
        resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyCeritificate);
        //NSLog(@"getCertificate: result code: %d", (int)resultCode);
        
        if(resultCode != noErr)
        {
            publicKeyCeritificate = NULL;
        }
    }
}


- (SecKeyRef)getPrivateKeyRefForTag:(NSData*)tag {
    @synchronized(instanceLock) {
        OSStatus resultCode = noErr;
        SecKeyRef privateKeyReference = NULL;
        
        NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
        
        // Set the private key query dictionary.
        [queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [queryPrivateKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPrivateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPrivateKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        
        // Get the key.
        resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyReference);
        
        if(resultCode != noErr)
        {
            privateKeyReference = NULL;
        }
        return privateKeyReference;
    }
}

- (SecKeyRef)getPrivateKeyRef {
    return [self getPrivateKeyRefForTag:privateTag];
}

- (SecKeyRef)getPrivateKeyRefForPublicKeyIdString:(NSString*) publicKeyIdString {
    @synchronized(instanceLock) {
        if (publicKeyIdString == nil) {
            return nil;
        }
        if ([publicKeyIdString isEqualToString:[CCRSA keyIdString:[CCRSA calcKeyId:[self getPublicKeyBits]]]]) {
            return [self getPrivateKeyRef];
        }
        return [self getPrivateKeyRefForTag:[self privateTagForKeyIdString:publicKeyIdString]];
    }
}

- (SecKeyRef)getPrivateKeyRefForPublicKeyId:(NSData*) publicKeyId {
    @synchronized(instanceLock) {
        
        if (publicKeyId == nil) {
            return nil;
        }
        if ([publicKeyId isEqualToData:[CCRSA calcKeyId:[self getPublicKeyBits]]]) {
            return [self getPrivateKeyRef];
        }
        return [self getPrivateKeyRefForTag:[self privateTagForKeyIdString:[CCRSA keyIdString:publicKeyId]]];
    }
}


- (NSData *)getPublicKeyBitsForTag:(NSData*)tag {
    @synchronized(instanceLock) {
        OSStatus sanityCheck = noErr;
        NSData * publicKeyBits = nil;
        
        NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];
        
        [queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [queryPublicKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPublicKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPublicKey setObject: @YES forKey:(__bridge id)kSecReturnData];
        
        CFDataRef publicKeyBitsCF;
        sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)queryPublicKey, (CFTypeRef *)&publicKeyBitsCF);
        
        if (sanityCheck != noErr)
        {
            publicKeyBits = nil;
        } else {
            publicKeyBits = (__bridge_transfer NSData *)publicKeyBitsCF;
        }
        
        return publicKeyBits;
    }
}

- (NSData *)getPublicKeyBits {
    return [self getPublicKeyBitsForTag:publicTag];
}

- (BOOL)addPublicKeyBits:(NSData*)publiceKeyBits {
    return [self addPublicKeyBits:publiceKeyBits withTag:publicTag];
}


- (NSData *)getPrivateKeyBitsForTag:(NSData*)tag {
    @synchronized(instanceLock) {
        OSStatus sanityCheck = noErr;
        NSData * privateKeyBits = nil;
        
        NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
        
        [queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [queryPrivateKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPrivateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPrivateKey setObject: @YES forKey:(__bridge id)kSecReturnData];
        
        CFDataRef privateKeyBitsCF;
        sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyBitsCF);
        
        if (sanityCheck != noErr)
        {
            privateKeyBits = nil;
        } else {
            privateKeyBits = (__bridge_transfer NSData *)privateKeyBitsCF;
        }
    	
        return privateKeyBits;
    }
}

- (NSData *)getPrivateKeyBits {
    return [self getPublicKeyBitsForTag:privateTag];
}


- (BOOL)addPrivateKeyBits:(NSData*)privateKeyBits withTag:(NSData*)tag {
    @synchronized(instanceLock) {
        NSMutableDictionary *privateKey = [[NSMutableDictionary alloc] init];
        [privateKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [privateKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [privateKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
        SecItemDelete((__bridge CFDictionaryRef)privateKey);
        
        CFTypeRef persistKey = nil;
        [privateKey setObject:privateKeyBits forKey:(__bridge id)kSecValueData];
        [privateKey setObject:(__bridge id) kSecAttrKeyClassPrivate forKey:(__bridge id)kSecAttrKeyClass];
        [privateKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnPersistentRef];
        
        OSStatus secStatus = SecItemAdd((__bridge CFDictionaryRef)privateKey, &persistKey);
        
        if (persistKey != nil) CFRelease(persistKey);
        
        if ((secStatus != noErr) && (secStatus != errSecDuplicateItem)) {
            NSLog(@"#ERROR: setPrivateKeyBits: Could not set private key.");
            return FALSE;
        }
        
        SecKeyRef keyRef = nil;
        [privateKey removeObjectForKey:(__bridge id)kSecValueData];
        [privateKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
        [privateKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
        [privateKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        
        SecItemCopyMatching((__bridge CFDictionaryRef)privateKey,(CFTypeRef *)&keyRef);
        
        if (!keyRef) {
            NSLog(@"#ERROR: setPrivateKeyBits: Could not set private key (2).");
            return FALSE;
        }
        if (keyRef) CFRelease(keyRef);
        return TRUE;
    }
}

-(BOOL)addPrivateKeyBits:(NSData*)privateKeyBits {
    return [self addPrivateKeyBits:privateKeyBits withTag:privateTag];
}

-(BOOL)cloneKeyPairKeys {
    @synchronized(instanceLock) {
        NSData * publicBits = [self getPublicKeyBits];
        if (publicBits == nil) {
            return NO;
        }
        NSData * privateBits = [self getPrivateKeyBits];
        if (publicBits == nil) {
            return NO;
        }
        
        NSString * publicKeyIdString = [CCRSA keyIdString:[CCRSA calcKeyId:publicBits]];
        NSData * publicTagSpec = [self publicTagForKeyIdString:publicKeyIdString];
        NSData * privateTagSpec = [self privateTagForKeyIdString:publicKeyIdString];
        
        if (RSA_DEBUG) NSLog(@"cloneKeyPairKeys, cloning private key to %@", [[NSString alloc] initWithData:privateTagSpec encoding:NSUTF8StringEncoding]);
        if (RSA_DEBUG) NSLog(@"cloneKeyPairKeys, cloning public key to %@", [[NSString alloc] initWithData:publicTagSpec encoding:NSUTF8StringEncoding]);
        
        if (![self addPrivateKeyBits:privateBits withTag:privateTagSpec]) {
            return NO;
        }
        if (![self addPublicKeyBits:publicBits withTag:publicTagSpec]) {
            return NO;
        };
        [self findKeyPairs];
        return YES;
    }
}

- (NSData *) publicTagForKeyIdString:(NSString *) keyIdString {
    @synchronized(instanceLock) {
        if (RSA_DEBUG) NSLog(@"publicTagForKeyIdString keyIdString = %@",keyIdString);
        
        NSString * tagStr = [NSString stringWithUTF8String:[publicTag bytes]];
        tagStr = [tagStr stringByAppendingString:@"."];
        tagStr = [tagStr stringByAppendingString:keyIdString];
        
        NSData * tag = [tagStr dataUsingEncoding:NSUTF8StringEncoding];
        if (RSA_DEBUG) NSLog(@"publicTagForKeyIdString, result %@", [[NSString alloc] initWithData:tag encoding:NSUTF8StringEncoding]);
        return tag;
    }
}

- (NSData *) privateTagForKeyIdString:(NSString *) keyIdString {
    @synchronized(instanceLock) {
        if (RSA_DEBUG) NSLog(@"privateTagForKeyIdString keyIdString = %@",keyIdString);
        
        NSString * tagStr = [NSString stringWithUTF8String:[privateTag bytes]];
        tagStr = [tagStr stringByAppendingString:@"."];
        tagStr = [tagStr stringByAppendingString:keyIdString];
        
        NSData * tag = [tagStr dataUsingEncoding:NSUTF8StringEncoding];
        if (RSA_DEBUG) NSLog(@"privateTagForKeyIdString, result %@", [[NSString alloc] initWithData:tag encoding:NSUTF8StringEncoding]);
        return tag;
    }
}

- (NSData *) publicTagForPeer:(NSString *) peerName {
    @synchronized(instanceLock) {
        if (RSA_DEBUG) NSLog(@"publicTagForPeer peerName = %@",peerName);
        
        NSString * tagStr = [NSString stringWithUTF8String:[publicPeerTag bytes]];
        tagStr = [tagStr stringByAppendingString:@"."];
        tagStr = [tagStr stringByAppendingString:peerName];
        
        NSData * tag = [tagStr dataUsingEncoding:NSUTF8StringEncoding];
        if (RSA_DEBUG) NSLog(@"publicTagForPeer, result %@", [[NSString alloc] initWithData:tag encoding:NSUTF8StringEncoding]);
        return tag;
    }
}


+ (NSData *) calcKeyId:(NSData *) myKeyBits {
    NSData * myKeyId = [[myKeyBits SHA256Hash] subdataWithRange:NSMakeRange(0, 8)];
    return myKeyId;
}

+ (NSString *) keyIdString:(NSData *) myKeyId {
    return [myKeyId hexadecimalString];
}

- (NSData *)stripPublicKeyHeader:(NSData *)d_key {
    // Skip ASN.1 public key header
    if (d_key == nil) return(nil);
    
    unsigned int len = [d_key length];
    if (!len) return(nil);
    
    unsigned char *c_key = (unsigned char *)[d_key bytes];
    unsigned int  idx    = 0;
    
    if (c_key[idx++] != 0x30) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    // PKCS #1 rsaEncryption szOID_RSA_RSA
    static unsigned char seqiod[] =
    { 0x30,   0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
        0x01, 0x05, 0x00 };
    if (memcmp(&c_key[idx], seqiod, 15)) return(nil);
    
    idx += 15;
    
    if (c_key[idx++] != 0x03) return(nil);
    
    if (c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    if (c_key[idx++] != '\0') return(nil);
    
    // Now make a new NSData from this buffer
    return([NSData dataWithBytes:&c_key[idx] length:len - idx]);
}


- (BOOL)addPublicPeerKey:(NSString *)key withPeerName:(NSString *)peerName {
    return [self addPublicKey:key withTag:[self publicTagForPeer:peerName]];
}

- (BOOL)addPublicKey:(NSString *)key withTag:(NSData *)tag {
    NSString *s_key = key;
    // This will be base64 encoded, decode it.
    NSData *d_key = [NSData dataWithBase64EncodedString:s_key];
    //d_key = [self stripPublicKeyHeader:d_key];
    if (d_key == nil) return(FALSE);
    return [self addPublicKeyBits: d_key withTag:tag];
}


- (BOOL)addPublicKeyBits:(NSData *)d_key withTag:(NSData *)d_tag {
    @synchronized(instanceLock) {
        
        // Delete any old lingering key with the same tag
        NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
        [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
        SecItemDelete((__bridge CFDictionaryRef)publicKey);
        
        CFTypeRef persistKey = nil;
        
        // Add persistent version of the key to system keychain
        [publicKey setObject:d_key forKey:(__bridge id)kSecValueData];
        [publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)kSecAttrKeyClass];
        [publicKey setObject: @YES forKey:(__bridge id)kSecReturnPersistentRef];
        
        OSStatus secStatus = SecItemAdd((__bridge CFDictionaryRef)publicKey, &persistKey);
        if (persistKey != nil) CFRelease(persistKey);
        
        if ((secStatus != noErr) && (secStatus != errSecDuplicateItem)) {
            return(FALSE);
        }
        
        // Now fetch the SecKeyRef version of the key
        SecKeyRef keyRef = nil;
        
        [publicKey removeObjectForKey:(__bridge id)kSecValueData];
        [publicKey removeObjectForKey:(__bridge id)kSecReturnPersistentRef];
        [publicKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        SecItemCopyMatching((__bridge CFDictionaryRef)publicKey,(CFTypeRef *)&keyRef);
        
        if (keyRef == nil) return(FALSE);
        
        return(TRUE);
    }
}

- (void)removePeerPublicKey:(NSString *)peerName {
    @synchronized(instanceLock) {
        
        //NSData * peerTag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];
        NSData * peerTag = [self publicTagForPeer:peerName];
        NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
        [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [publicKey setObject:peerTag forKey:(__bridge id)kSecAttrApplicationTag];
        SecItemDelete((__bridge CFDictionaryRef)publicKey);
    }
}

- (BOOL)deleteKeyPairKeys {
    @synchronized(instanceLock) {
        //[self cleanAllRSAKeys];
        // NSLog(@"Cleaning cleanKeyPairKeys");
        
        NSMutableDictionary * privateKey = [[NSMutableDictionary alloc] init];
        [privateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [privateKey setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
        [privateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        OSStatus myStatus = SecItemDelete((__bridge CFDictionaryRef)privateKey);
        // NSLog(@"SecItemDelete returned %ld on privateKey dict %@", myStatus, privateKey);
        
        
        NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
        [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [publicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        OSStatus myStatus2 = SecItemDelete((__bridge CFDictionaryRef)publicKey);
        // NSLog(@"SecItemDelete returned %ld on publicKey dict %@", myStatus, publicKey);
        return myStatus == noErr && myStatus2 == noErr;
    }
}

- (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef {
    @synchronized(instanceLock) {
        SecKeyRef keyRef = NULL;
        
        NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
        
        // Set the SecKeyRef query dictionary.
        [queryKey setObject:(__bridge id)persistentRef forKey:(__bridge id)kSecValuePersistentRef];
        [queryKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        
        // Get the persistent key reference.
        SecItemCopyMatching((__bridge CFDictionaryRef)queryKey, (CFTypeRef *)&keyRef);
        
        return keyRef;
    }
}

- (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)keyRef {
    @synchronized(instanceLock) {
        CFTypeRef persistentRef = NULL;
        
        NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
        
        // Set the PersistentKeyRef key query dictionary.
        [queryKey setObject:(__bridge id)keyRef forKey:(__bridge id)kSecValueRef];
        [queryKey setObject: @YES forKey:(__bridge id)kSecReturnPersistentRef];
        
        // Get the persistent key reference.
        SecItemCopyMatching((__bridge CFDictionaryRef)queryKey, (CFTypeRef *)&persistentRef);
        
        return persistentRef;
    }
}

- (SecKeyRef)getPeerKeyRef:(NSString *)peerName {
    @synchronized(instanceLock) {
        SecKeyRef persistentRef = NULL;
        
        //NSData *d_tag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];
        NSData * d_tag = [self publicTagForPeer:peerName];
        NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
        [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
        [publicKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
        [publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)kSecAttrKeyClass];
        
        OSStatus sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey,(CFTypeRef *)&persistentRef);
        
        if (sanityCheck != noErr) {
            if (persistentRef != NULL) {
                CFRelease(persistentRef);
            }
            persistentRef = NULL;
        }
        return persistentRef;
    }
    
}

- (NSData *)getKeyBitsForPeerRef:(NSString *)peerName {
    @synchronized(instanceLock) {
        OSStatus sanityCheck = noErr;
        NSData * publicKeyBits = nil;
        
        //NSData *d_tag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];
        NSData * d_tag = [self publicTagForPeer:peerName];
        
        NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
        [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
        [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
        [publicKey setObject: @YES forKey:(__bridge id)kSecReturnData];
        
        CFDataRef publicKeyBitsCF;
        sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&publicKeyBitsCF);
        
        if (sanityCheck != noErr) {
            publicKeyBits = nil;
        } else {
            publicKeyBits = (__bridge_transfer NSData *)publicKeyBitsCF;
        }
        
        return publicKeyBits;
    }
}


- (NSDictionary*) findKeypairsWithPrivatePrefix:(NSData*)privatePrefix withPublicPrefix:(NSData*) publicPrefix {
    @synchronized(instanceLock) {
        
        NSDictionary * query = @{(__bridge id) kSecClass: (__bridge id) kSecClassKey,
                                 (__bridge id) kSecAttrKeyType: (__bridge id) kSecAttrKeyTypeRSA,
                                 (__bridge id) kSecReturnAttributes: @YES,
                                 //(__bridge id) kSecAttrKeyClass: (__bridge id) kSecAttrKeyClassPrivate,
                                 (__bridge id) kSecMatchLimit: (__bridge id)kSecMatchLimitAll
                                 };
        
        // get search results
        CFTypeRef result = nil;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&result);
        
        id resultObj = CFBridgingRelease(result);
        //NSLog(@"resultObj = %@", resultObj);
        
        if (status == 0 && resultObj != nil) {
            // do something with the result
            int results = [resultObj count];
            NSMutableDictionary *found = [[NSMutableDictionary alloc] init];
            NSString * privatePrefixString = [NSString stringWithUTF8String:[privatePrefix bytes]];
            NSString * publicPrefixString = [NSString stringWithUTF8String:[publicPrefix bytes]];
            for (int i = 0; i < results;++i ) {
                //NSLog(@"result %d = %@",i,resultObj[i]);
                NSData * atag = resultObj[i][@"atag"];
                if (atag != nil ) {
                    NSString * tag;
                    if ([atag isKindOfClass:[NSData class]]) {
                        tag = [[NSString alloc] initWithData:atag encoding:NSUTF8StringEncoding];
                    } else if ([atag isKindOfClass:[NSString class]]){
                        tag = (NSString*)atag;
                    } else {
                        break;
                    }
                    //NSString * prefixString = [[NSString alloc] initWithData:prefix encoding:NSUTF8StringEncoding];
                    //NSLog(@"result %d = %@",i,resultObj[i]);
                    if (RSA_DEBUG) NSLog(@"tag %d = ‘%@‘",i,tag);
                    //NSLog(@"priv prefix %d = ‘%@‘",i,privatePrefixString);
                    //NSLog(@"pub  prefix %d = ‘%@‘",i,publicPrefixString);
                    NSString * postFix;
                    NSScanner * theScanner = [NSScanner scannerWithString:tag];
                    BOOL isPublic = [theScanner scanString:publicPrefixString intoString:NULL];
                    BOOL isPrivate = [theScanner scanString:privatePrefixString intoString:NULL];
                    BOOL s2 = [theScanner scanString:@"." intoString:NULL];
                    BOOL s3 = [theScanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&postFix];
                    if ((isPublic || isPrivate) && s2 && s3) {
                        //NSLog(@"postFix %d = %@",i,postFix);
                        if (found[postFix] == nil) {
                            found[postFix] = [[NSMutableDictionary alloc]init];
                        }
                        if (isPrivate) {
                            found[postFix][@"private"] = tag;
                        }
                        if (isPublic) {
                            found[postFix][@"public"] = tag;
                        }
                    } else {
                        // NSLog(@"no postfix");
                    }
                } else {
                    NSLog(@"Error no atag for item %d = %@",i,resultObj[i]);
                    
                }
            }
            if (RSA_DEBUG) NSLog(@"found=%@",found);
            return found;
        } else {
            NSLog(@"findKeyPairsWithPrefix: error OSStatus %d",(int)status);
            return nil;
        }
    }
}

- (BOOL) deleteAllRSAKeys {
    @synchronized(instanceLock) {
        
        NSDictionary * query = @{(__bridge id) kSecClass: (__bridge id) kSecClassKey,
                                 (__bridge id) kSecAttrKeyType: (__bridge id) kSecAttrKeyTypeRSA,
                                 (__bridge id) kSecReturnAttributes: @YES,
                                 //(__bridge id) kSecAttrKeyClass: (__bridge id) kSecAttrKeyClassPrivate,
                                 (__bridge id) kSecMatchLimit: (__bridge id)kSecMatchLimitAll
                                 };
        
        // get search results
        CFTypeRef result = nil;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&result);
        
        id resultObj = CFBridgingRelease(result);
        //NSLog(@"resultObj = %@", resultObj);
        
        
        int deleted = 0;
        if (status == 0 && resultObj != nil) {
            // do something with the result
            int results = [resultObj count];
            if (RSA_DEBUG) NSLog(@"deleteAllRSAKeys: found %d keys",results);
            for (int i = 0; i < results;++i ) {
                //NSLog(@"result %d = %@",i,resultObj[i]);
                NSData * atag = resultObj[i][@"atag"];
                if (atag != nil ) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    [dict setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
                    [dict setObject:atag forKey:(__bridge id)kSecAttrApplicationTag];
                    [dict setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
                    OSStatus myStatus = SecItemDelete((__bridge CFDictionaryRef)dict);
                    if (RSA_DEBUG) NSLog(@"SecItemDelete returned %ld on dict %@", myStatus, dict);
                    if (myStatus == 0) {
                        ++deleted;
                    }
                    
                } else {
                    NSLog(@"Error no atag for item %d = %@",i,resultObj[i]);
                }
            }
            NSLog(@"CCRA: deleted %d keys",deleted);
        } else {
            NSLog(@"cleanAllRSAKeys: find error OSStatus %d",(int)status);
        }
        return status == noErr;
    }
}


- (NSDictionary*) findKeyPairs {
    return [self findKeypairsWithPrivatePrefix:privateTag withPublicPrefix:publicTag];
}



static unsigned char oidSequence[] = { 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00 };

static NSString *x509PublicHeader = @"-----BEGIN PUBLIC KEY-----";
static NSString *x509PublicFooter = @"-----END PUBLIC KEY-----";
static NSString *pKCS1PublicHeader = @"-----BEGIN RSA PUBLIC KEY-----";
static NSString *pKCS1PublicFooter = @"-----END RSA PUBLIC KEY-----";
static NSString *pemPrivateHeader = @"-----BEGIN RSA PRIVATE KEY-----";
static NSString *pemPrivateFooter = @"-----END RSA PRIVATE KEY-----";

+ (NSString*)makeSSHFormattedPublicKey:(NSData *)publicKeyBits {
    char length[4] = {0,0,0,7};
    NSMutableData * data = [NSMutableData dataWithBytes:length length:4];
    NSString * stringToWriteInFile = @"ssh-rsa";
    [data appendData:[stringToWriteInFile dataUsingEncoding:NSUTF8StringEncoding]];
    length[3] = 3;
    [data appendBytes:length length:4];
    char version[3] = {1,0,1};
    [data appendBytes:version length:3];
    length[3] = [[CCRSA getPublicKeyMod:publicKeyBits] length];
    [data appendBytes:length length:4];
    [data appendData:[CCRSA getPublicKeyMod:publicKeyBits]];
    
    stringToWriteInFile = @"ssh-rsa ";
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:[data asBase64EncodedString:1]];
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:@" some.hostaddress.com\n"];
    
    return stringToWriteInFile;
}

+(NSString *)makeX509FormattedPublicKey:(NSData *)publicKeyBits {
    unsigned char builder[15];
    NSMutableData *encKey = [[NSMutableData alloc] init];
    int bitstringEncLength;
    if ([publicKeyBits length ] + 1 < 128 )
        bitstringEncLength = 1 ;
    else
        bitstringEncLength = (([publicKeyBits length ] +1 ) / 256) + 2 ;
    
    builder[0] = 0x30;
    size_t i = sizeof(oidSequence) + 2 + bitstringEncLength + [publicKeyBits length];
    size_t j = encodeLength(&builder[1], i);
    [encKey appendBytes:builder length:j +1];
    
    [encKey appendBytes:oidSequence length:sizeof(oidSequence)];
    
    builder[0] = 0x03;
    j = encodeLength(&builder[1], [publicKeyBits length] + 1);
    builder[j+1] = 0x00;
    [encKey appendBytes:builder length:j + 2];
    [encKey appendData:publicKeyBits];
    
    NSString *returnString = [NSString stringWithFormat:@"%@\n%@\n%@\n", x509PublicHeader, [encKey asBase64EncodedString:1], x509PublicFooter];
    //NSLog(@"PEM formatted key:\n%@",returnString);
    
    return returnString;
}

+(NSData*)extractPublicKeyBitsFromPEM:(NSString *)pemPublicKeyString {
    BOOL isX509 = NO;
    
    NSString * header, * footer;
    if (([pemPublicKeyString rangeOfString:x509PublicHeader].location != NSNotFound) &&
        ([pemPublicKeyString rangeOfString:x509PublicFooter].location != NSNotFound))
    {
        header = x509PublicHeader;
        footer = x509PublicFooter;
        isX509 = YES;
    } else if (([pemPublicKeyString rangeOfString:pKCS1PublicHeader].location != NSNotFound) &&
               ([pemPublicKeyString rangeOfString:pKCS1PublicFooter].location != NSNotFound))
    {
        header = pKCS1PublicHeader;
        footer = pKCS1PublicFooter;
        isX509 = NO;
    } else {
        NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format");
        return nil;
    }
    
    NSString *strippedKey = [self extractPayloadFromPEM: pemPublicKeyString header: header footer: footer];
    
    NSData *strippedPublicKeyData = [NSData dataWithBase64EncodedString:strippedKey];
    
    if (isX509) {
        unsigned char * bytes = (unsigned char *)[strippedPublicKeyData bytes];
        size_t bytesLen = [strippedPublicKeyData length];
        
        size_t i = 0;
        if (bytes[i++] != 0x30) {
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (2)");
            return nil;
        }
        
        /* Skip size bytes */
        if (bytes[i] > 0x80)
            i += bytes[i] - 0x80 + 1;
        else
            i++;
        
        if (i >= bytesLen){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (3)");
            return nil;
        }
        if (bytes[i] != 0x30){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (4)");
            return nil;
        }
        
        /* Skip OID */
        i += 15;
        
        if (i >= bytesLen - 2){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (5)");
            return nil;
        }
        if (bytes[i++] != 0x03){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (6)");
            return nil;
        }
        /* Skip length and null */
        if (bytes[i] > 0x80)
            i += bytes[i] - 0x80 + 1;
        else
            i++;
        
        if (i >= bytesLen){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (7)");
            return nil;
        }
        if (bytes[i++] != 0x00){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (8)");
            return nil;
        }
        if (i >= bytesLen){
            NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (9)");
            return nil;
        }
        strippedPublicKeyData = [NSData dataWithBytes:&bytes[i] length:bytesLen - i];
    }
    
    //NSLog(@"X.509 Formatted Public Key bytes:\n%@",[strippedPublicKeyData description]);
    
    if (strippedPublicKeyData == nil){
        NSLog(@"extractPrivateKeyBitsFromPEM: not in PEM format (2)");
        return nil;
    }
    //NSLog(@"Stripped Public Key Bytes:\n%@",[strippedPublicKeyData description]);
    return strippedPublicKeyData;
}

size_t encodeLength(unsigned char * buf, size_t length) {
    if (length < 128) {
        buf[0] = length;
        return 1;
    }
    
    size_t i = (length / 256) + 1;
    buf[0] = i + 0x80;
    for (size_t j = 0 ; j < i; ++j) {
        buf[i - j] = length & 0xFF;
        length = length >> 8;
    }
    
    return i + 1;
}

+(NSString*)makePEMFormattedPrivateKey:(NSData *)privateKeyBits {
    NSString * stringToWriteInFile = pemPrivateHeader;
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:@"\n"];
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:[privateKeyBits asBase64EncodedString:1]];
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:@"\n"];
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:pemPrivateFooter];
    stringToWriteInFile = [stringToWriteInFile stringByAppendingString:@"\n"];
    return stringToWriteInFile;
}

+(NSData*)extractPrivateKeyBitsFromPEM:(NSString *)pemPrivateKeyString {
    if (([pemPrivateKeyString rangeOfString:pemPrivateHeader].location != NSNotFound) && ([pemPrivateKeyString rangeOfString:pemPrivateFooter].location != NSNotFound))
    {
        NSString *strippedKey = [self extractPayloadFromPEM: pemPrivateKeyString header: pemPrivateHeader footer: pemPrivateFooter];
        if (RSA_DEBUG) NSLog(@"strippedkey:\n%@",strippedKey);
        return [NSData dataWithBase64EncodedString:strippedKey];
    }
    return nil;
}

+ (NSString*) extractPayloadFromPEM: (NSString*) pemString header: (NSString*) header footer: (NSString*) footer {
    NSRange headerRange = [pemString rangeOfString: header];
    NSRange footerRange = [pemString rangeOfString: footer];
    NSUInteger start = headerRange.location + headerRange.length;
    NSRange payloadRange = NSMakeRange(start, footerRange.location - start);
    
    return [[[[pemString substringWithRange: payloadRange]
              stringByReplacingOccurrencesOfString: @"\n" withString: @""]
             stringByReplacingOccurrencesOfString: @"\r" withString: @""]
            stringByReplacingOccurrencesOfString: @" "  withString: @""];
}

-(BOOL)importPrivateKeyBits:(NSString *)pemPrivateKeyString {
    NSData * myBits = [CCRSA extractPrivateKeyBitsFromPEM:pemPrivateKeyString];
    return [self addPrivateKeyBits:myBits withTag:privateTag];
}

- (BOOL) importPublicKeyBits: (NSString*) pemText withTag: (NSData*) tag {
    NSData * myBits = [CCRSA extractPublicKeyBitsFromPEM: pemText];
    return [self addPublicKeyBits: myBits withTag: tag];
}

- (BOOL) importKeypairFromPEM: (NSString*) pemText withPublicTag: (NSData*) tag {
    return [self importPrivateKeyBits: pemText] && [self importPublicKeyBits: pemText withTag: tag];
}

- (BOOL) importKeypairFromPEM: (NSString*) pemText {
    return [self importPrivateKeyBits: pemText] && [self importPublicKeyBits: pemText withTag: publicTag];
}

+ (int)derEncodingGetSizeFrom:(NSData*)buf at:(int*)iterator {
    const uint8_t* data = [buf bytes];
    int itr = *iterator;
    int num_bytes = 1;
    int ret = 0;
    
    if (data[itr] > 0x80) {
        num_bytes = data[itr] - 0x80;
        itr++;
    }
    
    for (int i = 0 ; i < num_bytes; i++) ret = (ret * 0x100) + data[itr + i];
    
    *iterator = itr + num_bytes;
    return ret;
}

+ (NSData *)getPublicKeyExp:(NSData *)publicKeyBits {
    if (publicKeyBits == nil) return nil;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:publicKeyBits at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    iterator += mod_size;
    
    iterator++; // TYPE - bit stream exp
    int exp_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    
    return [publicKeyBits subdataWithRange:NSMakeRange(iterator, exp_size)];
}

+ (NSData *)getPublicKeyMod:(NSData *)publicKeyBits {
    if (publicKeyBits == NULL) return NULL;
    
    int iterator = 0;
    
    iterator++; // TYPE - bit stream - mod + exp
    [self derEncodingGetSizeFrom:publicKeyBits at:&iterator]; // Total size
    
    iterator++; // TYPE - bit stream mod
    int mod_size = [self derEncodingGetSizeFrom:publicKeyBits at:&iterator];
    
    return [publicKeyBits subdataWithRange:NSMakeRange(iterator, mod_size)];
}

+ (int)getPublicKeySize:(NSData*)keyBits {
    @try {
        NSData * modulus = [CCRSA getPublicKeyMod:keyBits];
        return modulus.length * 8;
    } @catch (NSException* ex) {
        NSLog(@"#ERROR: getPublicKeySize exception: %@", ex);
    }
    return 0;
}

+ (NSData *)makeSignatureOf:(NSData *)hash withPrivateKey:(SecKeyRef)privateKey {
    OSStatus sanityCheck = noErr;
    NSData * signedHash = nil;
    size_t signedHashBytesSize = SecKeyGetBlockSize(privateKey);
    uint8_t * signedHashBytes = malloc(signedHashBytesSize * sizeof(uint8_t));
    memset((void *)signedHashBytes, 0x0, signedHashBytesSize);
    sanityCheck = SecKeyRawSign(privateKey,
                                kSecPaddingPKCS1SHA256,
                                [hash bytes],
                                CC_SHA256_DIGEST_LENGTH,
                                (uint8_t *)signedHashBytes,
                                &signedHashBytesSize);
    if (sanityCheck != noErr) {
        NSLog(@"makeSignatureOf failed with error: %d", (int)sanityCheck);
        if (signedHashBytes) free(signedHashBytes);
        return nil;
    }
    signedHash = [NSData dataWithBytes:(const void *)signedHashBytes length:(NSUInteger)signedHashBytesSize];
    if (signedHashBytes) free(signedHashBytes);
    return signedHash;
}

+ (BOOL) verifySignature:(NSData *)signature forHash:(NSData *)hash withPublicKey:(SecKeyRef)publicKey {
    OSStatus result = SecKeyRawVerify(publicKey, kSecPaddingPKCS1SHA256, [hash bytes], [hash length], [signature bytes], [signature length]);
    return (result == noErr) ? YES : NO;
}

@end
