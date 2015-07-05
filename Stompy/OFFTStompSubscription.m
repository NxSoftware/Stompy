//
//  OFFTStompSubscription.m
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompSubscription.h"

@interface OFFTStompSubscription ()
@property (nonatomic, copy) NSString *identifier;
@end

@implementation OFFTStompSubscription

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
    }
    return self;
}

@end
