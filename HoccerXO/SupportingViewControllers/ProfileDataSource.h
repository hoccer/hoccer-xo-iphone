//
//  ProfileDataSource.h
//  HoccerXO
//
//  Created by David Siegel on 05.06.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol ProfileDataSourceDelegate <NSObject>

@property (nonatomic,strong) UITableView* tableView;

- (void) configureCellAtIndexPath: (NSIndexPath*) indexPath;

@end

@protocol ProfileItemInfo <NSObject>

@property (nonatomic,readonly) NSString * name;

@end

@interface ProfileDataSource : NSObject
{
    NSArray * _currentModel;
}

@property (nonatomic,assign) id<ProfileDataSourceDelegate> delegate;
@property (nonatomic,readonly) NSUInteger count;

- (id) objectAtIndexedSubscript: (NSInteger) index;
- (void) updateModel: (NSArray*) newModel;

- (id) objectAtIndexPath: (NSIndexPath*) indexPath;
- (NSIndexPath*) indexPathForObject: (id) object;

@end

@interface ProfileSection : NSObject<ProfileItemInfo>
{
    NSMutableArray * _items;
}

@property (nonatomic,readonly) NSUInteger count;
@property (nonatomic,strong)   NSString* name;

- (id) objectAtIndexedSubscript: (NSInteger) index;

+ (id) sectionWithName: (NSString*) name items: (id) firstItem, ...;
+ (id) sectionWithName: (NSString*) name array: (NSArray*) items;

@end

