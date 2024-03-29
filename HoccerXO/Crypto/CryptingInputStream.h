//
//  EncryptingInputStream.h
//  EncryptingInputStream
//
//  Created by Pavel Mayer 17.4.2013
//  Copyright 2013 Hoccer GmbH. All rights reserved.
//  Based on Ideas from http://bjhomer.blogspot.de/2011/04/subclassing-nsinputstream.html
//

#import <Foundation/Foundation.h>
#import "CryptoEngine.h"


@interface CryptingInputStream : NSInputStream <NSStreamDelegate>

@property (nonatomic, strong) CryptoEngine * cryptoEngine;

- (id)initWithInputStream:(NSInputStream *)stream cryptoEngine:(CryptoEngine*)engine skipOutputBytes:(NSInteger)skipOutputBytes;

@end
