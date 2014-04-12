//
//  GroupInStatuNascendi.h
//  HoccerXO
//
//  Created by David Siegel on 12.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface GroupInStatuNascendi : NSObject

// properties we want filled in
@property (nonatomic, strong)   NSString       * nickName;
@property (nonatomic, strong)   UIImage        * avatarImage;
@property (nonatomic, readonly) NSMutableArray * members;

// mock properties to feel 'groupy' enough to run a contact sheet on this... thing
@property (nonatomic, readonly) BOOL             iAmAdmin;
@property (nonatomic, strong)   NSString       * relationshipState;
@property (nonatomic, strong)   NSString       * verifiedKey;
@property (nonatomic, strong)   NSArray        * messages;

@end
