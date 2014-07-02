//
//  HXOPluralocalizedString.m
//  HoccerXO
//
//  Created by David Siegel on 01.07.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOPluralocalizedString.h"

// http://unicode.org/repos/cldr-tmp/trunk/diff/supplemental/language_plural_rules.html

NSString * const kPluralCategoryZero  = @"zero";
NSString * const kPluralCategoryOne   = @"one";
NSString * const kPluralCategoryTwo   = @"two";
NSString * const kPluralCategoryFew   = @"few";
NSString * const kPluralCategoryMany  = @"many";
NSString * const kPluralCategoryOther = nil;

NSString * categoryForCount(int count) {
    NSString * code = NSLocalizedString(@"language_code", nil);
    if ([@[@"af", @"sq", @"asa", @"eu", @"bem", @"bez", @"bn", @"brx", @"bg",
           @"ca", @"chr", @"cgg", @"da", @"dv", @"nl", @"en", @"eo", @"et",
           @"ee", @"fo", @"fi", @"fur", @"gl", @"lg", @"de", @"el", @"gu",
           @"ha", @"haw", @"he", @"is", @"it", @"kaj", @"kl", @"kk", @"ku",
           @"lb", @"jmc", @"ml", @"mr", @"mas", @"mn", @"nah", @"ne", @"nd",
           @"no", @"nb", @"nn", @"ny", @"nyn", @"or", @"om", @"pap", @"ps",
           @"pt", @"pa", @"rm", @"rof", @"rwk", @"ssy", @"saq", @"seh", @"ksb",
           @"sn", @"xog", @"so", @"nr", @"st", @"es", @"sw", @"ss", @"sv",
           @"gsw", @"syr", @"ta", @"te", @"teo", @"tig", @"ts", @"tn", @"tk",
           @"kcg", @"ur", @"ve", @"vun", @"wae", @"fy", @"xh", @"zu"]
         indexOfObject: code] != NSNotFound)
    {
        if (count == 1) {
            return kPluralCategoryOne;
        } else {
            return kPluralCategoryOther;
        }
    } else if ([@[@"az", @"bm", @"my", @"zh", @"dz", @"ka", @"hu", @"ig", @"id",
                  @"ja", @"jv", @"kea", @"kn", @"km", @"ko", @"ses", @"lo",
                  @"kde", @"ms", @"fa", @"root", @"sah", @"sg", @"ii", @"th",
                  @"bo", @"to", @"tr", @"vi", @"wo", @"yo"]
                indexOfObject: code] != NSNotFound)
    {
        return kPluralCategoryOther;
    } else if ([@[@"ak", @"am", @"bh", @"fil", @"fr", @"ff", @"guw", @"hi",
                  @"kab", @"ln", @"mg", @"nso", @"tl", @"ti", @"wa"]
                indexOfObject: code] != NSNotFound)
    {
        if (count < 2) {
            return kPluralCategoryOne;
        } else {
            return kPluralCategoryOther;
        }
    } else if ([@[@"be", @"bs", @"hr", @"ru", @"sr", @"sh", @"uk"]
                indexOfObject: code] != NSNotFound)
    {
        int mod10 = count % 10;
        int mod100 = count % 100;
        if (mod10 == 1 && mod100 != 11) {
            return kPluralCategoryOne;
        } else if (mod10 >= 2 && mod10 <= 4 && ! (mod100 >= 12 && mod100 <= 14)) {
            return kPluralCategoryFew;
        } else if (mod10 == 0 || (mod10 >= 5 && mod10 <= 9) || (mod100 >= 11 && mod100 <= 14)) {
            return kPluralCategoryMany;
        } else {
            return kPluralCategoryOther;
        }
    }
    NSLog(@"Unhandled language %@", code);
    return nil;
}

NSString * HXOPluralocalizedString(NSString * key, int count, BOOL explicitZero) {
    NSString * keyWithCategory = HXOPluralocalizedKey(key, count, explicitZero);
    return NSLocalizedString(keyWithCategory, nil);
}

NSString * HXOPluralocalizedKey(NSString * key, int count, BOOL explicitZero) {
    NSString * category = explicitZero && count == 0 ? @"zero" : categoryForCount(count);
    return category ? [NSString stringWithFormat: @"%@ (%@)", key, category] : key;
}

