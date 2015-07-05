//
//  NXStompSocketRocketTransport.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompSocketRocketTransport.h"
#import "SRWebSocket.h"

typedef NS_ENUM(NSUInteger, NXSocketRocketErrorCode) {
    NXSocketRocketErrorCodeUpdgradeFailed = 2133,
};

@interface NXStompSocketRocketTransport () <SRWebSocketDelegate>

- (instancetype)initWithURLRequest:(NSURLRequest *)request NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)URL;

@property (nonatomic, strong) SRWebSocket *socket;

@property (nonatomic, copy) NSURLRequest *urlRequest;
@end

@implementation NXStompSocketRocketTransport
@synthesize delegate;

+ (NXStompSocketRocketTransport *)transportWithURL:(NSURL *)URL {
    return [[self alloc] initWithURL:URL];
}

+ (NXStompSocketRocketTransport *)transportWithURLRequest:(NSURLRequest *)request {
    return [[self alloc] initWithURLRequest:request];
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [self initWithURLRequest:[NSURLRequest requestWithURL:URL]];
    if (self) {
    }
    return self;
}

- (instancetype)initWithURLRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        _urlRequest = [request copy];
    }
    return self;
}

#pragma mark - Lazy Instantiation

- (SRWebSocket *)socket {
    if (_socket == nil) {
        _socket = [[SRWebSocket alloc] initWithURLRequest:self.urlRequest];
        _socket.delegate = self;
    }
    return _socket;
}

#pragma mark - Transport Methods

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

#pragma mark - Helpers

- (void)handleSocketClosed {
    _socket = nil;
    [self.delegate transportDidClose:self];
}

#pragma mark - Socket Rocket Delegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self.delegate transportDidOpen:self];
}

- (void)webSocket:(SRWebSocket *)webSocket
 didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean {
    [self handleSocketClosed];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"socket failedWithError: %@", error);
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
        if (error.code == ECONNREFUSED) {
            [self handleSocketClosed];
        }
    } else if ([error.domain isEqualToString:SRWebSocketErrorDomain]) {
        if (error.code == NXSocketRocketErrorCodeUpdgradeFailed) {
            [self handleSocketClosed];
        }
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self.delegate transport:self didReceiveMessage:message];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSLog(@"Socket received pong");
}

@end
