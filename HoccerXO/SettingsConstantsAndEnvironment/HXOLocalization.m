//
//  HXOLocalization.c
//  HoccerXO
//
//  Created by guido on 03.02.15.
//  Copyright (c) 2015 Hoccer GmbH. All rights reserved.
//

#import "HXOLocalization.h"
#import "HXOHyperLabel.h"

NSString* HXOAppName() {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}

NSString* HXOLocalizedString(NSString* key, NSString* comment, ...) {
    va_list args;
    va_start(args, comment);
    
    NSString* format = NSLocalizedString(key, comment);
    NSString* string = [[NSString alloc] initWithFormat:format arguments:args];
    
    va_end(args);
    return string;
}

// look in variant bundle first, then in general localization
NSString* HXOLabelledFullyLocalizedString(NSString* key, NSString* comment, ...) {
    va_list args;
    va_start(args, comment);
    
    NSString* bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    NSString * format = NSLocalizedStringFromTable(key, bundleName, comment);
    if ([key isEqualToString:format]) {
        format = NSLocalizedString(key, comment);
    }
    
    NSString * localizedString = [[NSString alloc] initWithFormat:format arguments:args];
    return localizedString;
}

NSString* HXOLabelledLocalizedString(NSString* key, NSString* comment, ...) {
    va_list args;
    va_start(args, comment);
    
    NSString* bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
    NSString * format = NSLocalizedStringFromTable(key, bundleName, comment);
    if ([key isEqualToString: format]) {
        NSLog(@"#ERROR: HXOLabelledLocalizedString: no label found for key '%@' in bundle '%@'", key, bundleName);
    }

    NSString * localizedString = [[NSString alloc] initWithFormat:format arguments:args];
    return localizedString;
}

NSAttributedString * HXOLocalizedStringWithLinks(NSString * key, NSString * comment) {
    NSError * error;
    NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern: @"\\[([^\\]]+)\\]\\(([^)]+)\\)" options: 0 error: &error];
    NSMutableString * text =  [NSMutableString stringWithString: HXOLabelledFullyLocalizedString(key, comment)];
    NSArray *results = [regex matchesInString: text options:kNilOptions range:NSMakeRange(0, text.length)];
    NSInteger offset = 0;
    NSMutableArray * linkRanges = [NSMutableArray array];
    NSMutableArray * urls = [NSMutableArray array];
    for (NSTextCheckingResult *result in results) {
        NSRange resultRange = [result range];
        resultRange.location += offset;
        NSString* match = [regex replacementStringForResult: result
                                                   inString: text
                                                     offset: offset
                                                   template: @"$1"];
        
        NSRange linkRange = [result rangeAtIndex: 1];
        linkRange.location += offset - 1; // eh ... compensate the opening bracket we are about to loose :-/
        
        NSRange urlRange = [result rangeAtIndex: 2];
        urlRange.location += offset;
        
        [linkRanges addObject: [NSValue valueWithRange: linkRange]];
        [urls addObject: [text substringWithRange: urlRange]];
        
        [text replaceCharactersInRange: resultRange withString: match];
        
        offset += [match length] - resultRange.length;
    }
    NSMutableAttributedString * result = [[NSMutableAttributedString alloc] initWithString: text attributes: nil];
    for (int i = 0; i < urls.count; ++i) {
        NSRange link = [linkRanges[i] rangeValue];
        NSString * url = urls[i];
        NSDictionary * attributes = @{kHXOLinkAttributeName: url};
        [result setAttributes: attributes range: link];
    }
    return result;
}
