//
//  NXStompClient.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompClient.h"
#import "NXStompAbstractTransport.h"
#import "NXStompFrame.h"

#define NXSTOMPDEBUG 1

#if NXSTOMPDEBUG
#define NXSTOMPLOG NSLog
#else
#define NXSTOMPLOG
#endif

NSString * const NXStompErrorDomain = @"NXStompErrorDomain";

// Standard frame headers
NSString * const NXStompHeaderAcceptVersion = @"accept-version";
NSString * const NXStompHeaderVersion       = @"version";
NSString * const NXStompHeaderHost          = @"host";
NSString * const NXStompHeaderReceipt       = @"receipt";

// Supported/accepted versions
typedef NS_ENUM(NSUInteger, NXStompVersion) {
    NXStompVersionUnknown,
    NXStompVersion1_1,
    NXStompVersion1_2,
};
NSString * const NXStompAcceptVersions = @"1.1,1.2";

typedef NS_ENUM(NSUInteger, NXStompState) {
    NXStompStateDisconnected,
    NXStompStateConnecting,
    NXStompStateConnected,
    NXStompStateDisconnecting,
};

typedef void(^NXStompReceiptHandler)();

@interface NXStompClient () <NXStompTransportDelegate>
@property (nonatomic, strong, nonnull) NXStompAbstractTransport *transport;
@property (nonatomic, copy) NSString *host;

/**
 * The versions of the STOMP protocol this client supports.
 */

/**
 * The version of the STOMP protocol to use as negotiated with the server.
 * Defaults to NXStompVersionUnknown until a connection has been established.
 */
@property (nonatomic, assign) NXStompVersion negotiatedVersion;

@property (nonatomic, assign) NXStompState state;

/**
 *  A counter that can be used to generate unique receipt headers.
 */
@property (nonatomic, assign) NSUInteger receiptCounter;

/**
 *  A dictionary of receipt headers : receipt handler blocks
 */
@property (nonatomic, copy) NSMutableDictionary *receiptHandlers;

@end

@implementation NXStompClient

+ (instancetype)stompWithTransport:(NXStompAbstractTransport *)transport {
    
    NXStompClient *client = [[self alloc] init];
    client.transport = transport;
    client.transport.delegate = client;
    return client;
}

#pragma mark - Public

- (void)connect {
    self.state = NXStompStateConnecting;
    [self.transport open];
}

- (void)disconnect {
    self.state = NXStompStateDisconnecting;

    NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandDisconnect];
    
    __weak typeof(self) weakSelf = self;
    [self sendFrame:frame withReceiptHandler:^{
        [weakSelf forceDisconnect];
    }];
}

#pragma mark - Transport Delegate

- (void)transportDidOpen:(NXStompAbstractTransport *)transport {
    
    // https://stomp.github.io/stomp-specification-1.2.html#CONNECT_or_STOMP_Frame
    // https://stomp.github.io/stomp-specification-1.1.html#CONNECT_or_STOMP_Frame
    
    // Construct the frame
    // 1.1 and 1.2 clients SHOULD continue to use the CONNECT command to remain backward compatible with STOMP 1.0 servers
    NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandConnect];
    
    [frame setHeader:NXStompHeaderAcceptVersion value:NXStompAcceptVersions];
    
    // TODO: This returns a bad connect ERROR from the server
    // Something to do with RabbitMQ
    [frame setHeader:NXStompHeaderHost value:[self.transport host]];
    
    // TODO: Heartbeat
    
    // TODO: Login & password
    
    [self sendFrame:frame];
}

- (void)transportDidClose:(NXStompAbstractTransport *)transport {
    
    // Wipe out the receipt handlers and reset the counter
    _receiptHandlers = nil;
    _receiptCounter = 0;
    
    self.state = NXStompStateDisconnected;
    [self.delegate stompClient:self didDisconnectWithError:nil];
}

- (void)transport:(NXStompAbstractTransport *)transport didReceiveMessage:(NSString *)message {
    NSLog(@"Received message: %@", message);
    
    NXStompFrame *frame = [self deserializeFrameFromString:message];
    
    if (self.state == NXStompStateConnecting) {
        // We're expecting either a CONNECTED frame...
        if (frame.command == NXStompFrameCommandConnected) {
            [self handleConnectedFrame:frame];
        }
        
        // or an ERROR
        else if (frame.command == NXStompFrameCommandError) {
            self.state = NXStompStateDisconnected;
            [self.delegate stompClient:self didDisconnectWithError:[NSError errorWithDomain:NXStompErrorDomain
                                                                                       code:NXStompConnectionError
                                                                                   userInfo:nil]];
        }
    }
    
    // Handle receipt frames
    if (frame.command == NXStompFrameCommandReceipt) {
        NSString *receipt = [frame valueForHeader:NXStompHeaderReceipt];
        NXStompReceiptHandler handler = _receiptHandlers[receipt];
        if (handler) {
            handler();
        }
    }
}

#pragma mark - Private

- (void)sendFrame:(NXStompFrame *)frame {
    if (self.state == NXStompStateDisconnecting
    && frame.command != NXStompFrameCommandDisconnect) {
        NSAssert(0, @"Cannot send frames while in the process of disconnecting");
        return;
    }
    
    NSData *serializedFrame = [self serializeFrame:frame];
    
#if NXSTOMPDEBUG
    NSLog(@"Sending message: %@", [[NSString alloc] initWithData:serializedFrame encoding:NSUTF8StringEncoding]);
#endif
    
    [self.transport sendData:serializedFrame];
}

- (void)sendFrame:(NXStompFrame *)frame withReceiptHandler:(NXStompReceiptHandler)receiptHandler {
    
    // Associate a receipt header with this frame before it is sent
    NSString *receipt = [NSString stringWithFormat:@"%lu", ++self.receiptCounter];
    [frame setHeader:NXStompHeaderReceipt value:receipt];
    
    // Track this receipt request
    self.receiptHandlers[receipt] = receiptHandler;
    
    [self sendFrame:frame];
}

- (void)forceDisconnect {
    [self.transport close];
}

#pragma mark - Private - Frame Handlers

- (void)handleConnectedFrame:(NXStompFrame *)frame {
    
    NSString *negotiatedVersion = [frame valueForHeader:NXStompHeaderVersion];
    if ([negotiatedVersion isEqualToString:@"1.2"]) {
        self.negotiatedVersion = NXStompVersion1_2;
    } else if ([negotiatedVersion isEqualToString:@"1.1"]) {
        self.negotiatedVersion = NXStompVersion1_1;
    } else {
        NSAssert(0, @"Somehow managed to negotiate to an unknown protocol version.");
    }
    
    self.state = NXStompStateConnected;
    [self.delegate stompClientDidConnect:self];
}

#pragma mark - Private - Utilities

- (NSString *)stringForCommand:(NXStompFrameCommand)command {
    switch (command) {
        case NXStompFrameCommandMessage:
            return @"MESSAGE";

        case NXStompFrameCommandSend:
            return @"SEND";
            
        case NXStompFrameCommandError:
            return @"ERROR";
            
        case NXStompFrameCommandReceipt:
            return @"RECEIPT";
            
        case NXStompFrameCommandConnect:
            return @"CONNECT";
            
        case NXStompFrameCommandConnected:
            return @"CONNECTED";
            
        case NXStompFrameCommandDisconnect:
            return @"DISCONNECT";
            
        default:
            return nil;
    }
}

- (NXStompFrameCommand)commandForString:(NSString *)commandString {
    if ([commandString isEqualToString:@"MESSAGE"]) {
        return NXStompFrameCommandMessage;
        
    } else if ([commandString isEqualToString:@"SEND"]) {
        return NXStompFrameCommandSend;
        
    } else if ([commandString isEqualToString:@"ERROR"]) {
        return NXStompFrameCommandError;
        
    } else if ([commandString isEqualToString:@"RECEIPT"]) {
        return NXStompFrameCommandReceipt;
        
    } else if ([commandString isEqualToString:@"CONNECT"]) {
        return NXStompFrameCommandConnect;
        
    } else if ([commandString isEqualToString:@"CONNECTED"]) {
        return NXStompFrameCommandConnected;
        
    } else if ([commandString isEqualToString:@"DISCONNECT"]) {
        return NXStompFrameCommandDisconnect;
        
    } else {
        return NXStompFrameCommandUnknown;
    }
}

#pragma mark - Private - Frame Conversion

- (NSData *)serializeFrame:(NXStompFrame *)frame {

    NSData *newline = [@"\x0A" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *nullByte = [@"\x00" dataUsingEncoding:NSUTF8StringEncoding];
    
    // Start with the command
    NSString *command = [self stringForCommand:frame.command];
    NSMutableData *data = [NSMutableData dataWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:newline];
    
    // Append the headers, each followed with a newline
    NSDictionary *frameHeaders = [frame allHeaders];
    for (NSString *key in frameHeaders) {
        NSString *headerLine = [NSString stringWithFormat:@"%@:%@", key, frameHeaders[key]];
        [data appendData:[headerLine dataUsingEncoding:NSUTF8StringEncoding]];
        [data appendData:newline];
    }
    
    // End the headers with an additional newline
    [data appendData:newline];
    
    // Append the body data or string
    if ([frame bodyData]) {
        [data appendData:[frame bodyData]];
    } else if ([frame bodyString]) {
        [data appendData:[[frame bodyString] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // End the frame with a NULL byte
    [data appendData:nullByte];
    
    return data;
}

- (NXStompFrame *)deserializeFrameFromString:(NSString *)frameString {
    NSArray *lines = [frameString componentsSeparatedByString:@"\n"];
    
    if (lines.count > 1) {
        
        NXStompFrameCommand command = [self commandForString:lines[0]];
        if (command != NXStompFrameCommandUnknown) {
            NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:command];
            
            // Parse headers
            for (int i=1; i < lines.count; ++i) {
                NSString *line = lines[i];
                NSUInteger indexOfFirstColon = [line rangeOfString:@":"].location;
                
                if (indexOfFirstColon == NSNotFound) {
                    break;
                }
                
                NSString *headerName = [line substringToIndex:indexOfFirstColon];
                NSString *headerValue = [line substringFromIndex:indexOfFirstColon + 1];
                
                [frame setHeader:headerName value:headerValue];
            }
            
            // TODO: Body
            
            return frame;
        }
    }
        
    return nil;
}

#pragma mark - Lazy Instantiation

- (NSMutableDictionary *)receiptHandlers {
    if (_receiptHandlers == nil) {
        _receiptHandlers = [[NSMutableDictionary alloc] init];
    }
    return _receiptHandlers;
}

@end
