//
//  NXStompSocketRocketTransport.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompSocketRocketTransport.h"
#import "SRWebSocket.h"

@interface NXStompSocketRocketTransport () <SRWebSocketDelegate>
@property (nonatomic, strong) SRWebSocket *socket;
@end

@implementation NXStompSocketRocketTransport

+ (NXStompSocketRocketTransport *)transportWithURL:(NSURL *)URL {
    return [[self alloc] initWithURL:URL];
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        self.socket = [[SRWebSocket alloc] initWithURL:URL];
        self.socket.delegate = self;
    }
    return self;
}

#pragma mark - Transport Overrides

- (NSString *)host {
    return self.socket.url.host;
}

- (void)open {
    [self.socket open];
}

- (void)close {
    [self.socket close];
}

- (void)sendData:(NSData *)data {
    [self.socket send:data];
}

#pragma mark - Socket Rocket Delegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self.delegate transportDidOpen:self];
}

- (void)webSocket:(SRWebSocket *)webSocket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    [self.delegate transportDidClose:self];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"socket failedWithError: %@", error);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self.delegate transport:self didReceiveMessage:message];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSLog(@"Socket received pong");
}

@end
