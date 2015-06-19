//
//  NXStompClient.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompClient.h"
#import "NXStompTransportAdapter.h"
#import "NXStompFrame.h"
#import "NXStompSubscription.h"

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
NSString * const NXStompHeaderDestination   = @"destination";
NSString * const NXStompHeaderContentLength = @"content-length";
NSString * const NXStompHeaderID            = @"id";

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
@property (nonatomic, strong, nonnull) id<NXStompTransportAdapter> transport;
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

+ (instancetype)stompWithTransport:(id<NXStompTransportAdapter>)transport {
    
    NXStompClient *client = [[self alloc] init];
    client.transport = transport;
    client.transport.delegate = client;
    return client;
}

#pragma mark - Public - Connection

// TODO: login & passcode support
// http://stomp.github.io/stomp-specification-1.2.html#CONNECT_or_STOMP_Frame
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

#pragma mark - Public - Sending Messages

- (void)sendMessage:(NSString *)message
      toDestination:(NSString *)destination {
    [self sendMessage:message
        toDestination:destination
    withCustomHeaders:nil];
}

- (void)sendMessage:(NSString *)message
      toDestination:(NSString *)destination
  withCustomHeaders:(NSDictionary *)headers {
    [self sendMessageData:[message dataUsingEncoding:NSUTF8StringEncoding]
            toDestination:destination
        withCustomHeaders:headers];
}

- (void)sendMessageData:(NSData *)messageData
          toDestination:(NSString *)destination {
    [self sendMessageData:messageData
            toDestination:destination
        withCustomHeaders:nil];
}

- (void)sendMessageData:(NSData *)messageData
          toDestination:(NSString *)destination
      withCustomHeaders:(NSDictionary *)headers {

    __block BOOL invalidHeaders = NO;

    __block NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandSend];
    
    // Add the user defined headers, ensuring they are comprised only of strings
    [headers enumerateKeysAndObjectsUsingBlock:^(id header, id value, BOOL *stop) {
        if ([header isKindOfClass:[NSString class]]
        && [value isKindOfClass:[NSString class]]) {
            
            [frame setHeader:header value:value];
            
        } else {
            NSAssert(0, @"Custom headers (and their values) must be strings.");
            *stop = YES;
            invalidHeaders = YES;
        }
    }];
    
    // Needed if NS_BLOCK_ASSERTIONS is enabled
    if (invalidHeaders) {
        return;
    }
    
    [frame setHeader:NXStompHeaderDestination value:destination];
    [frame setHeader:NXStompHeaderContentLength
               value:[NSString stringWithFormat:@"%ld", messageData.length]];
    [frame setBody:messageData];
    
    [self sendFrame:frame];
}

#pragma mark - Public - Subscriptions

- (id)subscribe:(NSString *)destination {
    
    NSString *identifier = [[NSUUID UUID] UUIDString];
    
    NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandSubscribe];
    [frame setHeader:NXStompHeaderDestination value:destination];
    [frame setHeader:NXStompHeaderID value:identifier];
    
    [self sendFrame:frame];
    
    return [[NXStompSubscription alloc] initWithIdentifier:identifier];
}

- (void)unsubscribe:(id)subscription {
    // Protection
    if ([subscription isKindOfClass:[NXStompSubscription class]] == NO) {
        NSAssert(0, @"You must provide an NXStompSubscription object.");
        return;
    }
    
    NSString *identifier = [(NXStompSubscription *)subscription identifier];
    
    NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandUnsubscribe];
    [frame setHeader:NXStompHeaderID value:identifier];
    
    [self sendFrame:frame];
}

#pragma mark - Transport Delegate

- (void)transportDidOpen:(id<NXStompTransportAdapter>)transport {
    
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

- (void)transportDidClose:(id<NXStompTransportAdapter>)transport {
    
    // Wipe out the receipt handlers and reset the counter
    _receiptHandlers = nil;
    _receiptCounter = 0;
    
    self.state = NXStompStateDisconnected;
    [self.delegate stompClient:self didDisconnectWithError:nil];
}

- (void)transport:(id<NXStompTransportAdapter>)transport didReceiveMessage:(NSString *)message {
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
        
        // Do no further message processing
        return;
    }
    
    // Handle regular messages
    if (frame.command == NXStompFrameCommandMessage) {
        [self handleMessageFrame:frame];
    }
    // Handle receipt frames
    else if (frame.command == NXStompFrameCommandReceipt) {
        NSString *receipt = [frame valueForHeader:NXStompHeaderReceipt];
        NXStompReceiptHandler handler = _receiptHandlers[receipt];
        if (handler) {
            handler();
            [_receiptHandlers removeObjectForKey:receipt];
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

- (void)handleMessageFrame:(NXStompFrame *)frame {
    
    // Data version of delegate method takes precendence
    if ([self.delegate respondsToSelector:@selector(stompClient:receivedMessageData:withHeaders:)]) {
        
        [self.delegate stompClient:self
               receivedMessageData:[frame body]
                       withHeaders:[frame allHeaders]];
        
    }
    // Fall back to the string-based delegate method
    else if ([self.delegate respondsToSelector:@selector(stompClient:receivedMessage:withHeaders:)]) {
        
        NSString *message = [[NSString alloc] initWithData:frame.body
                                                  encoding:NSUTF8StringEncoding];
        [self.delegate stompClient:self
                   receivedMessage:message
                       withHeaders:[frame allHeaders]];
        
    }
}

#pragma mark - Private - Utilities

- (NSString *)stringForCommand:(NXStompFrameCommand)command {
    switch (command) {
        case NXStompFrameCommandMessage:
            return @"MESSAGE";

        case NXStompFrameCommandSend:
            return @"SEND";
            
        case NXStompFrameCommandSubscribe:
            return @"SUBSCRIBE";
            
        case NXStompFrameCommandUnsubscribe:
            return @"UNSUBSCRIBE";
            
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
        
    } else if ([commandString isEqualToString:@"SUBSCRIBE"]) {
        return NXStompFrameCommandSubscribe;
        
    } else if ([commandString isEqualToString:@"UNSUBSCRIBE"]) {
        return NXStompFrameCommandUnsubscribe;
        
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
        
        // TODO: escape colons
        // http://stomp.github.io/stomp-specification-1.1.html#Value_Encoding
        
        NSString *headerLine = [NSString stringWithFormat:@"%@:%@", key, frameHeaders[key]];
        [data appendData:[headerLine dataUsingEncoding:NSUTF8StringEncoding]];
        [data appendData:newline];
    }
    
    // End the headers with an additional newline
    [data appendData:newline];
    
    // Append the body data
    if (frame.body) {
        [data appendData:frame.body];
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
                
                // TODO: decode colons
                // http://stomp.github.io/stomp-specification-1.1.html#Value_Encoding
                
                NSString *line = lines[i];
                NSUInteger indexOfFirstColon = [line rangeOfString:@":"].location;
                
                if (indexOfFirstColon == NSNotFound) {
                    break;
                }
                
                NSString *headerName = [line substringToIndex:indexOfFirstColon];
                NSString *headerValue = [line substringFromIndex:indexOfFirstColon + 1];
                
                // Don't overwrite existing headers
                // http://stomp.github.io/stomp-specification-1.2.html#Repeated_Header_Entries
                // http://stomp.github.io/stomp-specification-1.1.html#Repeated_Header_Entries
                if ([frame valueForHeader:headerName] == nil) {
                    [frame setHeader:headerName value:headerValue];
                }
            }
            
            // Parse the body
            if (frame.mayHaveBody) {
                if ([lines.lastObject isKindOfClass:[NSString class]]) {
                    
                    // TODO: Read exactly header[content-length]
                    // NOTE: Dealing with UTF-8 strings will render this
                    // impossible if NULLs are present within the body.
                    // Will likely need to use NSData throughout.
                    
                    NSData *body = [lines.lastObject dataUsingEncoding:NSUTF8StringEncoding];
                    
                    // The body will include the trailing NULL
                    frame.body = [body subdataWithRange:NSMakeRange(0, body.length - 1)];
                } else {
                    NSAssert(0, @"Unexpected frame body type: %@", [lines.lastObject class]);
                }
            }
            
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
