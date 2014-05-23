//
//  NSObject+DelegateHelper.m
//  Hoccer
//
//  Created by Robert Palmer on 07.09.09.
//  Copyright 2009 Hoccer GmbH. All rights reserved.
//

#import "NSObject+DelegateHelper.h"


@implementation NSObject (DelegateHelper)

- (id)checkAndPerformSelector: (SEL)aSelector {
	if (![self respondsToSelector:aSelector]) {
		return nil;
	}

    IMP imp = [self methodForSelector: aSelector];
    id (*func)(id, SEL) = (void *)imp;
    return func(self, aSelector);
}

- (id)checkAndPerformSelector: (SEL)aSelector withObject: (id)aObject {
	if (![self respondsToSelector:aSelector]) {
		return nil;
	}

    IMP imp = [self methodForSelector: aSelector];
    id (*func)(id, SEL, id) = (void *)imp;
    return func(self, aSelector, aObject);
}

- (id)checkAndPerformSelector: (SEL)aSelector withObject: (id)firstObject withObject: (id)secondObject {
	if (![self respondsToSelector:aSelector]) {
		return nil;
	}
    IMP imp = [self methodForSelector: aSelector];
    id (*func)(id, SEL, id, id) = (void *)imp;
    return func(self, aSelector, firstObject, secondObject);
}

@end
