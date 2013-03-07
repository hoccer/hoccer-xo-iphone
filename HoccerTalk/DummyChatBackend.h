//
//  DummyChatBackend.h
//  HoccerTalk
//
//  Created by David Siegel on 28.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatBackend.h"

@interface DummyChatBackend : ChatBackend

@property (nonatomic, strong) NSArray* blubberMessages;

- (id) init;
- (void) addDummies: (long) messageCount;

@end
