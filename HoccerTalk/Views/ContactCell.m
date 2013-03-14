//
//  ContactCell.m
//  HoccerTalk
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactCell.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

@interface ContactCell ()

@end

@implementation ContactCell

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}

@end
