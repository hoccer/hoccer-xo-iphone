//
//  HXOMarkdownParser.h
//  HoccerXO
//
//  Created by David Siegel on 16.02.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

struct sd_markdown;

@interface HXOMarkdownRenderer : NSObject
{
    struct sd_markdown * sd_;
    NSMutableArray     * stack_;
    NSMutableArray     * marks_;
}
- (NSAttributedString*) render: (NSString*) markdown;

- (void) blockCode: (NSString*) text lang: (NSString*) lang;
- (void) blockQuote: (NSString*) text;
- (void) header: (NSString*) text level: (int) level;
- (void) hrule;
- (void) list: (NSString*) text flags: (int) flags;
- (void) listItem: (NSString*) text flags: (int) flags;
- (void) paragraph: (NSString*) text;

- (int) codeSpan: (NSString*) text;
- (int) doubleEmphasis: (NSString*) text;
- (int) emphasis: (NSString*) text;
- (int) image: (NSString*) link title: (NSString*) title alt: (NSString*) alt;
- (int) linebreak;
- (int) link: (NSString*) link title: (NSString*) title content: (NSString*) alt;
- (int) tripleEmphasis: (NSString*) text;
- (int) strikethrough: (NSString*) text;
- (int) superscript: (NSString*) text;

- (void) entity: (NSString*) entity;
- (void) normalText: (NSString*) text;

- (void) docHeader;

@end
