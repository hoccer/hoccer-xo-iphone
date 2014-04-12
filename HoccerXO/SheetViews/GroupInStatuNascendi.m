//
//  GroupInStatuNascendi.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "GroupInStatuNascendi.h"

#import "DatasheetController.h"

@implementation GroupInStatuNascendi

@synthesize members = _members;
- (NSMutableArray*) members {
    if ( ! _members) {
        _members = [NSMutableArray array];
        [_members addObject: self];
    }
    return _members;
}

- (BOOL) iAmAdmin { return YES; }

@end
