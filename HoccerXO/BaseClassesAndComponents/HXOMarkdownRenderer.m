//
//  HXOMarkdownParser.m
//  HoccerXO
//
//  Created by David Siegel on 16.02.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "HXOMarkdownRenderer.h"

#import "markdown.h"

NSString *
NSStringFromBuf(const struct buf * b) {
    return [[NSString alloc] initWithBytes: b->data length: b->size encoding: NSUTF8StringEncoding];
}


@implementation HXOMarkdownRenderer
- (id) init {
    self = [super init];
    if (self) {
        sd_ = sd_markdown_new(0, 16, [[self class] callbacks], (__bridge void *)(self));
        stack_ = [NSMutableArray array];
        marks_ = [NSMutableArray array];
    }
    return self;
}

- (void) dealloc {
    sd_markdown_free(sd_);
}
- (NSAttributedString*) render: (NSString*) markdown {
    [marks_ addObject: @(stack_.count)];
    struct buf * ob = bufnew(64);
    sd_markdown_render(ob, (uint8_t*)markdown.UTF8String, [markdown lengthOfBytesUsingEncoding: NSUTF8StringEncoding], sd_);
    bufrelease(ob);
    [marks_ removeLastObject];
    NSMutableAttributedString * doc = [[NSMutableAttributedString alloc] init];
    for (id block in stack_) {
        [doc appendAttributedString: block];
    }
    [stack_ removeAllObjects];
    return doc;
}

#define RENDERER (__bridge HXOMarkdownRenderer*)opaque
#define _(s) NSStringFromBuf(s)

void HXOMarkdownBlockCode(struct buf * ob, const struct buf * text, const struct buf * lang, void * opaque) {
    [RENDERER blockCode: _(text) lang: _(lang)];
}

- (void) blockCode: (NSString*) text lang: (NSString*) lang {
}

void HXOMarkdownBlockQuote(struct buf * ob, const struct buf * text, void * opaque) {
    [RENDERER blockQuote: _(text)];
}

- (void) blockQuote: (NSString*) text {

}

void HXOMarkdownHeader(struct buf *ob, const struct buf *text, int level, void *opaque) {
    [RENDERER header: _(text) level: level];
}

- (void) header: (NSString*) text level: (int) level{

}

void HXOMarkdownHRule(struct buf *ob, void *opaque) {
    [RENDERER hrule];
}

- (void) hrule {

}

void HXOMarkdownList(struct buf *ob, const struct buf *text, int flags, void *opaque) {
    [RENDERER list: _(text) flags: flags];
}

- (void) list: (NSString*) text flags: (int) flags {

}

void HXOMarkdownListItem(struct buf *ob, const struct buf *text, int flags, void *opaque) {
    [RENDERER listItem: _(text) flags: flags];
}

- (void) listItem: (NSString*) text flags: (int) flags {

}

void HXOMarkdownParagraph(struct buf *ob, const struct buf *text, void *opaque) {
    [RENDERER paragraph: _(text)];
}

- (void) paragraph: (NSString*) text {
    NSMutableAttributedString * s = [[NSMutableAttributedString alloc] init];
    int mark = [[marks_ lastObject] intValue];
    [marks_ removeLastObject];
    for (int i = mark; i < stack_.count; ++i) {
        id span = stack_[i];
        if ([span isKindOfClass: [NSString class]]) {
            span = [[NSAttributedString alloc] initWithString: span];
        }
        [s appendAttributedString: span];
    }
    while (stack_.count > mark) {
        [stack_ removeLastObject];
    }
    [stack_ addObject: s];
    [marks_ addObject: @(stack_.count)];
}

int HXOMarkdownCodeSpan(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER codeSpan: _(text)];
}

- (int) codeSpan: (NSString*) text {
    return 1;
}

int HXOMarkdownDoubleEmphasis(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER doubleEmphasis: _(text)];
}

- (int) doubleEmphasis: (NSString*) text {
    return 1;
}

int HXOMarkdownEmphasis(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER emphasis: _(text)];
}

- (int) emphasis: (NSString*) text {
    id top = [stack_ lastObject];
    [stack_ removeLastObject];
    NSDictionary * attributes = @{NSForegroundColorAttributeName: [UIColor blueColor]};
    if ([top isKindOfClass: [NSMutableAttributedString class]]) {
        [top addAttributes: attributes range: NSMakeRange(0, 0)];
    } else {
        top = [[NSMutableAttributedString alloc] initWithString: top attributes: attributes];
    }
    [stack_ addObject: top];
    return 1;
}

int HXOMarkdownImage(struct buf *ob, const struct buf *link, const struct buf *title, const struct buf *alt, void *opaque) {
    return [RENDERER image: _(link) title: _(title) alt: _(alt)];
}

- (int) image: (NSString*) link title: (NSString*) title alt: (NSString*) alt {
    return 1;
}

int HXOMarkdownLinebreak(struct buf *ob, void *opaque) {
    return [RENDERER linebreak];
}

- (int) linebreak {
    return 1;
}

int HXOMarkdownLink(struct buf *ob, const struct buf *link, const struct buf *title, const struct buf *content, void *opaque) {
    return [RENDERER link: _(link) title: _(title) content: _(content)];
}

- (int) link: (NSString*) link title: (NSString*) title content: (NSString*) alt {
    return 1;
}

int HXOMarkdownTripleEmphasis(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER tripleEmphasis: _(text)];
}

- (int) tripleEmphasis: (NSString*) text {
    return 1;
}

int HXOMarkdownStrikethrough(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER strikethrough: _(text)];
}

- (int) strikethrough: (NSString*) text {
    return 1;
}

int HXOMarkdownSuperscript(struct buf *ob, const struct buf *text, void *opaque) {
    return [RENDERER superscript: _(text)];
}

- (int) superscript: (NSString*) text {
    return 1;
}

void HXOMarkdownEntity(struct buf *ob, const struct buf *entity, void *opaque) {
    [RENDERER entity: _(entity)];
}

- (void) entity: (NSString*) entity {

}

void HXOMarkdownNormalText(struct buf *ob, const struct buf *text, void *opaque) {
    [RENDERER normalText: _(text)];
}

- (void) normalText: (NSString*) text {
    [stack_ addObject: text];
}

void HXOMarkdownDocHeader(struct buf *ob, void *opaque) {
    [RENDERER docHeader];
}

- (void) docHeader {

}

#undef RENDERER
#undef _

+ (struct sd_callbacks*) callbacks {
    static struct sd_callbacks callbacks;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        callbacks.blockcode = HXOMarkdownBlockCode;
        callbacks.blockquote = HXOMarkdownBlockQuote;
        callbacks.header = HXOMarkdownHeader;
        callbacks.hrule = HXOMarkdownHRule;
        callbacks.list = HXOMarkdownList;
        callbacks.listitem = HXOMarkdownListItem;
        callbacks.paragraph = HXOMarkdownParagraph;
        callbacks.codespan = HXOMarkdownCodeSpan;
        callbacks.double_emphasis = HXOMarkdownDoubleEmphasis;
        callbacks.emphasis = HXOMarkdownEmphasis;
        callbacks.image = HXOMarkdownImage;
        callbacks.linebreak = HXOMarkdownLinebreak;
        callbacks.link = HXOMarkdownLink;
        callbacks.triple_emphasis = HXOMarkdownTripleEmphasis;
        callbacks.strikethrough = HXOMarkdownStrikethrough;
        callbacks.superscript = HXOMarkdownSuperscript;
        callbacks.entity = HXOMarkdownEntity;
        callbacks.normal_text = HXOMarkdownNormalText;
        callbacks.doc_header = HXOMarkdownDocHeader;
    });

    return &callbacks;
}

@end
