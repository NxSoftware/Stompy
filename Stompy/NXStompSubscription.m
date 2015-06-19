//
//  NXStompSubscription.m
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompSubscription.h"

@interface NXStompSubscription ()
@property (nonatomic, copy) NSString *identifier;
@end

@implementation NXStompSubscription

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
    }
    return self;
}

@end
