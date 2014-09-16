//
//  HXOPluralocalization.h
//  HoccerXO
//
//  Created by David Siegel on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString * HXOPluralocalizeInt(NSString * key, NSUInteger count);
NSString * HXOPluralocalizedString(NSString * key, NSUInteger count, BOOL explicitZero);
NSString * HXOPluralocalizedKey(NSString * key, NSUInteger count, BOOL explicitZero);