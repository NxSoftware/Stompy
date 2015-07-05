//
//  OFFTStompGCDAsyncSocketTransport.m
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompGCDAsyncSocketTransport.h"
#import "GCDAsyncSocket.h"

#define GCDAsyncSocketLoggingEnabled 1

@interface OFFTStompGCDAsyncSocketTransport () <GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;

@property (nonatomic, copy) NSString *host;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) NSTimeInterval connectionTimeout;

@end

@implementation OFFTStompGCDAsyncSocketTransport
@synthesize delegate;

+ (OFFTStompGCDAsyncSocketTransport *)transportWithHost:(NSString *)host
                                                 port:(uint16_t)port
                                    connectionTimeout:(NSTimeInterval)connectionTimeout {
    
    return [[self alloc] initWithHost:host port:port connectionTimeout:connectionTimeout];
}

- (instancetype)initWithHost:(NSString *)host
                        port:(uint16_t)port
           connectionTimeout:(NSTimeInterval)connectionTimeout {
    self = [super init];
    if (self) {
        _host = [host copy];
        _port = port;
        _connectionTimeout = connectionTimeout;
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    }
    return self;
}

#pragma mark - Transport Methods

- (void)open {
    NSError *error = nil;
    [self.socket connectToHost:_host
                        onPort:_port
                   withTimeout:_connectionTimeout
                         error:&error];
}

- (void)close {
    [self.socket disconnectAfterWriting];
}

//- (NSString *)host {
//    return [NSString stringWithFormat:@"%@:%hu", _host, _port];
//}

- (void)sendData:(NSData *)data {
    [self.socket writeData:data withTimeout:-1 tag:0];
    [self.socket readDataWithTimeout:-1 tag:0];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [self.delegate transportDidOpen:self];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self.delegate transportDidClose:self];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"Incoming!");
}

@end
