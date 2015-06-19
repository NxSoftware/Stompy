//
//  NXStompSubscription.h
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NXStompSubscription : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier;

- (NSString *)identifier;

@end
