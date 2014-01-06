//
//  MessageItem.h
//  HoccerXO
//
//  Created by David Siegel on 21.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HXOMessage;

@interface MessageItem : NSObject

- (id) initWithMessage: (HXOMessage*) message;

@property (nonatomic,weak) HXOMessage * message;

@property (nonatomic,readonly) NSAttributedString * attributedBody;

@property (nonatomic,readonly) NSString * vcardName;
@property (nonatomic,readonly) NSString * vcardOrganization;
@property (nonatomic,readonly) NSString * vcardEmail;

@property (nonatomic,readonly) NSString * audioTitle;
@property (nonatomic,readonly) NSString * audioArtist;
@property (nonatomic,readonly) NSString * audioAlbum;
@property (nonatomic,readonly) NSTimeInterval audioDuration;


@property (nonatomic,readonly) BOOL attachmentInfoLoaded;



@end
