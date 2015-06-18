//
//  NXStompAbstractTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NXStompAbstractTransport;

@protocol NXStompTransportDelegate <NSObject>

- (void)transportDidConnect:(NXStompAbstractTransport *)transport;

- (void)transport:(NXStompAbstractTransport *)transport didReceiveMessage:(NSString *)message;

@end

@interface NXStompAbstractTransport : NSObject

@property (nonatomic, weak) id<NXStompTransportDelegate> delegate;

- (NSString *)host;

- (void)connect;

- (void)sendData:(NSData *)data;

@end