//
//  OFFTStompAbstractTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol OFFTStompTransportAdapter;

@protocol OFFTStompTransportDelegate <NSObject>

- (void)transportDidOpen:(id<OFFTStompTransportAdapter>)transport;
- (void)transportDidClose:(id<OFFTStompTransportAdapter>)transport;

- (void)transport:(id<OFFTStompTransportAdapter>)transport didReceiveMessage:(NSString *)message;

@end

@protocol OFFTStompTransportAdapter <NSObject>

@property (nonatomic, weak) id<OFFTStompTransportDelegate> delegate;

- (NSString *)host;

- (void)open;
- (void)close;

- (void)sendData:(NSData *)data;

@end
