
//
//  RSA.m
//  Hoccer
//
//  Created by Robert Palmer on 23.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//
//

#import "RSA.h"
#import "NSData+Base64.h"
#import "NSData+HexString.h"
#import "NSString+RandomString.h"


#import "HXOBackend.h" // debug, remove later



@implementation RSA

const size_t BUFFER_SIZE = 64;
const size_t CIPHER_BUFFER_SIZE = 1024;
const uint32_t PADDING = kSecPaddingPKCS1;

static const uint8_t publicKeyIdentifier[]  = "com.hoccertalk.client.publickey";
static const uint8_t privateKeyIdentifier[] = "com.hoccertalk.client.privatekey";

SecKeyRef publicKey;
SecKeyRef privateKey; 

static RSA *instance;

+ (RSA*)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RSA alloc] init];
        if ([instance getPrivateKeyRef] == nil || [instance getPublicKeyRef] == nil) {
            NSLog(@"There are no RSA keys, generate them...");
            [instance generateKeyPairKeys];
        }
    }); 
    //[instance getCertificate];
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        privateTag = [[NSData alloc] initWithBytes:privateKeyIdentifier length:sizeof(privateKeyIdentifier)];
        publicTag = [[NSData alloc] initWithBytes:publicKeyIdentifier length:sizeof(publicKeyIdentifier)];
    }

    return self;
}

- (NSString *)generateRandomString:(NSUInteger)length {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!§$%&/()=?";
    return [NSString stringWithRandomCharactersOfLength: length usingCharacterSet: letters];
}

- (void)generateKeyPairKeys
{
    // NSLog(@"Generating RSA Keys");
    OSStatus status = noErr;	
    NSMutableDictionary *privateKeyAttr = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *publicKeyAttr = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *keyPairAttr = [[NSMutableDictionary alloc] init];
	
    publicKey = NULL;
    privateKey = NULL;
	
    [privateKeyAttr setObject: @YES forKey:(__bridge id)kSecAttrIsPermanent];
    [privateKeyAttr setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
    
    [publicKeyAttr setObject: @YES forKey:(__bridge id)kSecAttrIsPermanent];
	[publicKeyAttr setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    
    [keyPairAttr setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [keyPairAttr setObject:@1024 forKey:(__bridge id)kSecAttrKeySizeInBits];
    
    [keyPairAttr setObject:privateKeyAttr forKey:(__bridge id)kSecPrivateKeyAttrs];
	[keyPairAttr setObject:publicKeyAttr forKey:(__bridge id)kSecPublicKeyAttrs];
	
    status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKey, &privateKey);
    
    if (status != noErr) {
        NSLog(@"generateKeyPairKeys: something went wrong %d", (int)status);
    }else {
        NSLog(@"generateKeyPairKeys: successfully generated RSA key pairs");
    }
    
    // NSLog(@"pubkey : %@", [[self getPublicKeyBits] hexadecimalString]);
    // NSLog(@"privkey: %@", [[self getPrivateKeyBits] hexadecimalString]);

    // NSLog(@"pubkeyid : %@", [HXOBackend ownPublicKeyIdString]);

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
        //NSLog(@"Error encrypring, OSStatus: %d", (NSInteger)status);
    }
        
    cipher = [NSData dataWithBytes:(const void *)cipherBuffer length:(NSUInteger)cipherBufferSize];
    if (cipherBuffer) { free(cipherBuffer); }
    
    return cipher;
}

- (NSData *)decryptWithKey: (SecKeyRef)key cipherData: (NSData *)cipherData {
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
        //NSLog(@"Error decrypting, OSStatus = %d", (NSInteger)status);
        NSNotification *notification = [NSNotification notificationWithName:@"encryptionError" object:self];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }
    
    //NSLog(@"decoded %d bytes, status %d", (NSInteger)plainBufferSize, (NSInteger)status);
    plainData = [NSData dataWithBytes:plainBuffer length:plainBufferSize];
    
    if (plainBuffer) { free(plainBuffer); }
    return plainData;
}


/* do we need that? - pavel
- (void)encryptWithPublicKey:(uint8_t *)plainBuffer cipherBuffer:(uint8_t *)cipherBuffer
{	
    OSStatus status = noErr;	
	
    size_t plainBufferSize = strlen((char *)plainBuffer);
    size_t cipherBufferSize = CIPHER_BUFFER_SIZE;
	SecKeyRef key = [self getPublicKeyRef];
    //NSLog(@"SecKeyGetBlockSize() public = %d", (int)SecKeyGetBlockSize(key));
    
    //  Error handling
    // Encrypt using the public.
    status = SecKeyEncrypt(key,
                           PADDING,
                           plainBuffer,
                           plainBufferSize,
                           &cipherBuffer[0],
                           &cipherBufferSize
                           );
    //NSLog(@"encryption result code: %d (size: %d)", (int)status, (int)cipherBufferSize);
    //NSLog(@"encrypted text: %s", cipherBuffer);
}
 

- (void)decryptWithPrivateKey:(uint8_t *)cipherBuffer plainBuffer:(uint8_t *)plainBuffer
{
    OSStatus status = noErr;
	
    size_t cipherBufferSize = strlen((char *)cipherBuffer);
	
    //NSLog(@"decryptWithPrivateKey: length of buffer: %d", (int)BUFFER_SIZE);
    //NSLog(@"decryptWithPrivateKey: length of input: %d", (int)cipherBufferSize);
	
    // DECRYPTION
    size_t plainBufferSize = BUFFER_SIZE;
	
    //  Error handling
    status = SecKeyDecrypt([self getPrivateKeyRef],
                           PADDING,
                           &cipherBuffer[0],
                           cipherBufferSize,
                           &plainBuffer[0],
                           &plainBufferSize
                           );
    //NSLog(@"decryption result code: %d (size: %d)", (int)status, (int)plainBufferSize);
    //NSLog(@"FINAL decrypted text: %s", plainBuffer);
	
}
 
 */


- (SecKeyRef)getPublicKeyRef {
    OSStatus resultCode = noErr;
    SecKeyRef publicKeyReference = NULL;
	
    if(publicKey == NULL) {
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
		
        publicKey = publicKeyReference;
    } 
	
    return publicKey;
}

- (void)getCertificate {
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


- (SecKeyRef)getPrivateKeyRef {
    OSStatus resultCode = noErr;
    SecKeyRef privateKeyReference = NULL;
	
    if(privateKey == NULL) {
        NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];

        // Set the private key query dictionary.
        [queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
        [queryPrivateKey setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
        [queryPrivateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
        [queryPrivateKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
		
        // Get the key.
        resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyReference);
		
        if(resultCode != noErr)
        {
            privateKeyReference = NULL;
        }
        privateKey = privateKeyReference;
    }
    
    return privateKey;
}

- (NSData *)getPublicKeyBits {
	OSStatus sanityCheck = noErr;
	NSData * publicKeyBits = nil;
	
	NSMutableDictionary * queryPublicKey = [[NSMutableDictionary alloc] init];

	[queryPublicKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
	[queryPublicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
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

- (NSData *)getPrivateKeyBits {
	OSStatus sanityCheck = noErr;
	NSData * privateKeyBits = nil;
	
	NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
    
	[queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
	[queryPrivateKey setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
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

- (NSData *)stripPublicKeyHeader:(NSData *)d_key
{
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

- (BOOL)addPublicKey:(NSString *)key withTag:(NSString *)tag
{
    NSString *s_key = key;
    // This will be base64 encoded, decode it.
    NSData *d_key = [NSData dataWithBase64EncodedString:s_key];
    //d_key = [self stripPublicKeyHeader:d_key];
    if (d_key == nil) return(FALSE);
    
    NSData *d_tag = [NSData dataWithBytes:[tag UTF8String] length:[tag length]];
    
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

- (void)removePeerPublicKey:(NSString *)peerName {
	
	NSData * peerTag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];
    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [publicKey setObject:peerTag forKey:(__bridge id)kSecAttrApplicationTag];
    SecItemDelete((__bridge CFDictionaryRef)publicKey);
}

- (void)cleanKeyChain {
    // NSLog(@"Cleaning keychain");

    NSMutableDictionary * privateKey = [[NSMutableDictionary alloc] init];
	[privateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
	[privateKey setObject:privateTag forKey:(__bridge id)kSecAttrApplicationTag];
	[privateKey setObject:(__bridge id)kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    OSStatus myStatus = SecItemDelete((__bridge CFDictionaryRef)privateKey);
    NSLog(@"SecItemDelete returned %ld on privateKey dict %@", myStatus, privateKey);

    
    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
	[publicKey setObject:publicTag forKey:(__bridge id)kSecAttrApplicationTag];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    myStatus = SecItemDelete((__bridge CFDictionaryRef)publicKey);
    NSLog(@"SecItemDelete returned %ld on publicKey dict %@", myStatus, publicKey);
    
    [self generateKeyPairKeys];
}

- (SecKeyRef)getKeyRefWithPersistentKeyRef:(CFTypeRef)persistentRef {
	SecKeyRef keyRef = NULL;
	
	NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
	
	// Set the SecKeyRef query dictionary.
	[queryKey setObject:(__bridge id)persistentRef forKey:(__bridge id)kSecValuePersistentRef];
	[queryKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
	
	// Get the persistent key reference.
	SecItemCopyMatching((__bridge CFDictionaryRef)queryKey, (CFTypeRef *)&keyRef);
    
    return keyRef;
}

- (CFTypeRef)getPersistentKeyRefWithKeyRef:(SecKeyRef)keyRef {
	CFTypeRef persistentRef = NULL;
	
	NSMutableDictionary * queryKey = [[NSMutableDictionary alloc] init];
	
	// Set the PersistentKeyRef key query dictionary.
	[queryKey setObject:(__bridge id)keyRef forKey:(__bridge id)kSecValueRef];
	[queryKey setObject: @YES forKey:(__bridge id)kSecReturnPersistentRef];
	
	// Get the persistent key reference.
	 SecItemCopyMatching((__bridge CFDictionaryRef)queryKey, (CFTypeRef *)&persistentRef);
	
	return persistentRef;
}

- (SecKeyRef)getPeerKeyRef:(NSString *)peerName {
    SecKeyRef persistentRef = NULL;
	
    NSData *d_tag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];
    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
    [publicKey setObject: @YES forKey:(__bridge id)kSecReturnRef];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];    
    [publicKey setObject:(__bridge id) kSecAttrKeyClassPublic forKey:(__bridge id)kSecAttrKeyClass];
    SecItemCopyMatching((__bridge CFDictionaryRef)publicKey,(CFTypeRef *)&persistentRef);
        
    return persistentRef;

}

- (NSData *)getKeyBitsForPeerRef:(NSString *)peerName {
	OSStatus sanityCheck = noErr;
	NSData * publicKeyBits = nil;
	
    NSData *d_tag = [NSData dataWithBytes:[peerName UTF8String] length:[peerName length]];

    NSMutableDictionary *publicKey = [[NSMutableDictionary alloc] init];
    [publicKey setObject:(__bridge id) kSecClassKey forKey:(__bridge id)kSecClass];
    [publicKey setObject:(__bridge id) kSecAttrKeyTypeRSA forKey:(__bridge id)kSecAttrKeyType];
    [publicKey setObject:d_tag forKey:(__bridge id)kSecAttrApplicationTag];
    [publicKey setObject: @YES forKey:(__bridge id)kSecReturnData];
    
    CFDataRef publicKeyBitsCF;
	sanityCheck = SecItemCopyMatching((__bridge CFDictionaryRef)publicKey, (CFTypeRef *)&publicKeyBitsCF);
    
	if (sanityCheck != noErr)
	{
		publicKeyBits = nil;
	} else {
        publicKeyBits = (__bridge_transfer NSData *)publicKeyBitsCF;
    }
        	
	return publicKeyBits;
}

@end
