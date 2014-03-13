//
//  OpenSSLCrypto.h
//  HoccerXO
//
//  Created by PM on 13.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpenSSLCrypto : NSObject

+ (BOOL)makeRSAKeyPairPEMWithSize:(int)bits withPublicKey:(NSString**)pubkey withPrivateKey:(NSString**)privkey;

@end
