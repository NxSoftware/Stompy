//
//  NXStompAbstractTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NXStompTransportAdapter;

@protocol NXStompTransportDelegate <NSObject>

- (void)transportDidOpen:(id<NXStompTransportAdapter>)transport;
- (void)transportDidClose:(id<NXStompTransportAdapter>)transport;

- (void)transport:(id<NXStompTransportAdapter>)transport didReceiveMessage:(NSString *)message;

@end

@protocol NXStompTransportAdapter <NSObject>

@property (nonatomic, weak) id<NXStompTransportDelegate> delegate;

- (NSString *)host;

- (void)open;
- (void)close;

- (void)sendData:(NSData *)data;

@end
