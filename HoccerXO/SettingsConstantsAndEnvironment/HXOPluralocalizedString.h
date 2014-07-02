//
//  HXOPluralocalizedString.h
//  HoccerXO
//
//  Created by David Siegel on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString * HXOPluralocalizedString(NSString * key, int count, BOOL explicitZero);
NSString * HXOPluralocalizedKey(NSString * key, int count, BOOL explicitZero);