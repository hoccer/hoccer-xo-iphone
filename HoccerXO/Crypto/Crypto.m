//
//  Crypto.m
//  Hoccer
//
//  Created by Robert Palmer on 17.06.11.
//  Copyright 2011 Hoccer GmbH. All rights reserved.
//

#import "NSData+CommonCrypto.h"

#import "Crypto.h"
#import "NSString+StringWithData.h"
#import "NSData+Base64.h"
#import "RSA.h"
#import "PublicKeyManager.h"

// fixed salt for testing
static NSData * NotSoRandomSalt() {
    NSMutableData *data = [NSMutableData data];
    
    for (NSInteger i = 1; i < 33; i++) {
        char c = (char)i;
        [data appendBytes:&c length:sizeof(char)];
    }
    
    return data;    
}

static NSData * RandomBytes(size_t count) {
    NSMutableData* data = [NSMutableData dataWithLength:count];
    int err = SecRandomCopyBytes(kSecRandomDefault, count, [data mutableBytes]);
    if (err != 0) {
        NSLog(@"RandomBytes; RNG error = %d", errno);
    }
    return [data copy];
}

static NSData * RandomSalt() {
    return RandomBytes(32);
}


@implementation NoCryptor

- (NSData *)encrypt:(NSData *)data {
    return data;
}

- (NSData *)decrypt:(NSData *)data {
    return data;
}

- (NSString *)encryptString: (NSString *)string {
	
    return string;
}

- (NSString *)decryptString: (NSString *)string {
    return string;
}

- (void)appendInfoToDictionary:(NSMutableDictionary *)dictionary {
    // not encryption - nothing to do here
}

@end

@interface AESCryptor ()
- (NSData *)saltedKeyHash;
@end


@implementation AESCryptor

+ (NSData *)random256BitKey {
    return RandomBytes(32);
}

- (id)initWithKey: (NSString *)theKey {
    return [self initWithKey:theKey salt:RandomSalt()];
}

- (id)initWithKey:(NSString *)theKey salt: (NSData *)theSalt {
    self = [self init];
    if (self) {
        key  = theKey;        
        salt = theSalt;
    }
    return self;
}

- (id)initWithRandomKey{
    NSString *theKey = [[RSA sharedInstance] generateRandomString:64];
    return [self initWithKey:theKey salt:RandomSalt()];
}

- (id)initWithRandomKeyWithSalt:(NSData *)theSalt{
    NSString *theKey = [[RSA sharedInstance] generateRandomString:64];
    return [self initWithKey:theKey salt:theSalt];
}

- (NSData *)encrypt:(NSData *)data {
    return [data AES256EncryptedDataUsingKey:[self saltedKeyHash] error:nil];
}

- (NSData *)decrypt:(NSData *)data {
    return [data decryptedAES256DataUsingKey:[self saltedKeyHash] error:nil];
}

- (NSString *)encryptString: (NSString *)string {
    NSData *data      = [string dataUsingEncoding:NSUTF8StringEncoding];
    // NSLog(@"encryptString data=%@", data);
    NSData *encripted = [self encrypt:data];
    // NSLog(@"encryptString encripted=%@", encripted);
    return [encripted asBase64EncodedString];
}

- (NSString *)decryptString: (NSString *)string {
    NSData *data      = [NSData dataWithBase64EncodedString:string];
    // NSLog(@"decryptString:data crypted=%@", data);
    NSData *decrypted = [self decrypt:data];
    // NSLog(@"decryptString: decrypted=%@", decrypted);
    return [NSString stringWithData:decrypted usingEncoding:NSUTF8StringEncoding];
}

- (void)appendInfoToDictionary: (NSMutableDictionary *)dictionary {
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"sendPassword"]){
        NSDictionary *cryptedPassword = [self getEncryptedRandomStringForClient];
        if (cryptedPassword!=nil){
            NSDictionary *encryption = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"AES", @"method",
                                    @256, @"keysize",
                                    [salt asBase64EncodedString], @"salt", 
                                    @"SHA256", @"hash", cryptedPassword, @"password", nil];

    
            [dictionary setObject:encryption forKey:@"encryption"];
        }
        else {
            NSNotification *notification = [NSNotification notificationWithName:@"noPublicKey" object:self];
            [[NSNotificationCenter defaultCenter] postNotification:notification];
        }
    }
    else {
        NSDictionary *encryption = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"AES", @"method",
                                    @256, @"keysize",
                                    [salt asBase64EncodedString], @"salt", 
                                    @"SHA256", @"hash", nil];
        
        
        [dictionary setObject:encryption forKey:@"encryption"];

    }
    
}


- (NSDictionary *)getEncryptedRandomStringForClient {
    
    NSArray *selectedClients;
    PublicKeyManager *keyManager = [[PublicKeyManager alloc]init];
    
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"selected_clients"] !=nil){
           selectedClients = [[NSUserDefaults standardUserDefaults] arrayForKey:@"selected_clients"];
        
        if (selectedClients.count == 0 ){
            return nil;
        }
        else {
            NSDictionary *toReturn = [[NSMutableDictionary alloc]initWithCapacity:selectedClients.count];
            
            for (NSDictionary *aClient in selectedClients){
                
                NSString *thePass = [[NSUserDefaults standardUserDefaults] stringForKey:@"encryptionKey"];
                NSData *passData = [thePass dataUsingEncoding:NSUTF8StringEncoding];
                SecKeyRef theKeyRef = [keyManager getKeyForClient:aClient];            
                if (theKeyRef != nil){
        
                    NSData *cipher = [[RSA sharedInstance] encryptWithKey:theKeyRef plainData:passData];
                    [toReturn setValue:[cipher asBase64EncodedString] forKey:[aClient objectForKey:@"id"]];
                }
            }
            return toReturn;
        }
    }
    return nil;
}


#pragma mark -
#pragma mark Private Methods
- (NSData *)saltedKeyHash {
    NSMutableData *saltedKey = [[key dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [saltedKey appendData:salt];
    return [[saltedKey SHA256Hash] subdataWithRange:NSMakeRange(0, 32)];
}


@end