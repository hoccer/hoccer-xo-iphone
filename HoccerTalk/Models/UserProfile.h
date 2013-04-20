//
//  UserProfile.h
//  HoccerTalk
//
//  Created by David Siegel on 20.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

// NOT a core data model, but a model nonetheless. 

@interface UserProfile : NSObject

@property (nonatomic,strong) NSString * nickName;

+ (UserProfile*) myProfile;

@end
