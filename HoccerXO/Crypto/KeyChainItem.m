//
//  KeyChainItem.m
//  HoccerXO
//
//  Created by pavel on 11.05.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//
// based on https://gist.github.com/btjones/10287581
// also considers:
// http://useyourloaf.com/blog/2010/04/28/keychain-duplicate-item-when-adding-password.html
// and
// http://stackoverflow.com/questions/22403734/keychain-item-reported-as-errsecitemnotfound-but-receive-errsecduplicateitem-o
//

#import "KeyChainItem.h"

#import <Security/Security.h>

@interface KeyChainItem() {
    NSString * _service;
    NSString * _account;
    id _data;
}
@end

@implementation KeyChainItem

@dynamic data;
@dynamic exists;

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)service account:(NSString *)account {

    return [NSMutableDictionary dictionaryWithDictionary:
            @{ (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
               (__bridge id)kSecAttrService : service,
               (__bridge id)kSecAttrAccount : account
            }];
}
/*
+(NSString*)secErrorString:(OSStatus)secStatus {
    return (__bridge NSString *) SecCopyErrorMessageString(secStatus, NULL);
}
*/

+(NSError*) NSFromOSError:(OSStatus)osStatus {
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
}

+ (BOOL)saveData:(NSString *)service account:(NSString *)account data:(id)data {
    
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service account:account];
    OSStatus secStatus = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    NSLog(@"KeyChainAccess:save: deleting possible old data for service %@ account %@ returned error = %d", service, account, (int)secStatus);
    
    keychainQuery[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    @try {
        NSData * archive = [NSKeyedArchiver archivedDataWithRootObject:data];
        if (archive != nil) {
            keychainQuery[(__bridge id)kSecValueData] = archive;
            
            OSStatus secStatus = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
            if (secStatus != noErr) {
                NSLog(@"KeyChainAccess:save: failed to save data for service %@ account %@, error = %d %@", service, account, (int)secStatus,[KeyChainItem NSFromOSError:secStatus]);
                return NO;
            }
        } else {
            NSLog(@"Archive creation for data '%@' service '%@' account '%@' failed.", data, service, account);
            return NO;
        }
    }
    @catch (NSException *e) {
        NSLog(@"Archive creation for data '%@' service '%@' account '%@' failed, exception=%@", data, service, account, e);
        return NO;
    }
    @finally {
    }
    return YES;
}

+ (id)loadData:(NSString *)service account:(NSString *)account {
    id ret = nil;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service account:account];
    keychainQuery[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
    keychainQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
 
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
        }
        @catch (NSException *e) {
            NSLog(@"Unarchive of %@ failed: %@", service, e);
        }
        @finally {}
    }
    if (keyData) CFRelease(keyData);
    return ret;
}

+ (BOOL)deleteData:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service account:account];
    OSStatus secStatus = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    if (secStatus != noErr) {
        NSLog(@"KeyChainAccess:save: failed to delete data for service %@ account %@, error = %d", service, account, (int)secStatus);
        return NO;
    }
    return YES;
}

- (id)initWithService: (NSString *)service account:(NSString *) account {
    
    if (self = [super init]) {
        _service = service;
        _account = account;
        _data = [KeyChainItem loadData:_service account:_account];
    }
    return self;
}

-(BOOL) deleteItem {
    if ([KeyChainItem deleteData:_service account:_account]) {
        _data = nil;
        return YES;
    }
    return NO;
}

-(void)setData:(id)theData {
    if (theData != nil) {
        if ([KeyChainItem saveData:_service account:_account data:theData]) {
            _data = [KeyChainItem loadData:_service account:_account];
        }
    } else {
        NSLog(@"KeyChainItem:setData: must not set to nil, use deleteItem");
    }
}

-(id)data {
    if (_data) {
        return _data;
    }
    _data = [KeyChainItem loadData:_service account:_account];
    return _data;
}

-(BOOL)exists {
    return _data != nil;
}


@end
