//
//  OFFTStompClient.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompClient.h"
#import "OFFTStompTransportAdapter.h"
#import "OFFTStompFrame.h"
#import "OFFTStompSubscription.h"

#define OFFTSTOMPDEBUG 1

#if OFFTSTOMPDEBUG
#define OFFTSTOMPLOG NSLog
#else
#define OFFTSTOMPLOG
#endif

NSString * const OFFTStompErrorDomain = @"OFFTStompErrorDomain";

// Standard frame headers
NSString * const OFFTStompHeaderAcceptVersion = @"accept-version";
NSString * const OFFTStompHeaderVersion       = @"version";
NSString * const OFFTStompHeaderHost          = @"host";
NSString * const OFFTStompHeaderReceipt       = @"receipt";
NSString * const OFFTStompHeaderDestination   = @"destination";
NSString * const OFFTStompHeaderContentLength = @"content-length";
NSString * const OFFTStompHeaderID            = @"id";

// Supported/accepted versions
typedef NS_ENUM(NSUInteger, OFFTStompVersion) {
    OFFTStompVersionUnknown,
    OFFTStompVersion1_1,
    OFFTStompVersion1_2,
};
NSString * const OFFTStompAcceptVersions = @"1.1,1.2";

typedef NS_ENUM(NSUInteger, OFFTStompState) {
    OFFTStompStateDisconnected,
    OFFTStompStateConnecting,
    OFFTStompStateConnected,
    OFFTStompStateDisconnecting,
};

typedef void(^OFFTStompReceiptHandler)();

@interface OFFTStompClient () <OFFTStompTransportDelegate>
@property (nonatomic, strong, nonnull) id<OFFTStompTransportAdapter> transport;
@property (nonatomic, copy) NSString *host;

/**
 * The versions of the STOMP protocol this client supports.
 */

/**
 * The version of the STOMP protocol to use as negotiated with the server.
 * Defaults to OFFTStompVersionUnknown until a connection has been established.
 */
@property (nonatomic, assign) OFFTStompVersion negotiatedVersion;

@property (nonatomic, assign) OFFTStompState state;

/**
 *  A counter that can be used to generate unique receipt headers.
 */
@property (nonatomic, assign) NSUInteger receiptCounter;

/**
 *  A dictionary of receipt headers : receipt handler blocks
 */
@property (nonatomic, copy) NSMutableDictionary *receiptHandlers;

@end

@implementation OFFTStompClient

+ (instancetype)stompWithTransport:(id<OFFTStompTransportAdapter>)transport {
    
    OFFTStompClient *client = [[self alloc] init];
    client.transport = transport;
    client.transport.delegate = client;
    return client;
}

#pragma mark - Public - Connection

// TODO: login & passcode support
// http://stomp.github.io/stomp-specification-1.2.html#CONNECT_or_STOMP_Frame
- (void)connect {
    self.state = OFFTStompStateConnecting;
    [self.transport open];
}

- (void)disconnect {
    self.state = OFFTStompStateDisconnecting;

    OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:OFFTStompFrameCommandDisconnect];
    
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

    __block OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:OFFTStompFrameCommandSend];
    
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
    
    [frame setHeader:OFFTStompHeaderDestination value:destination];
    [frame setHeader:OFFTStompHeaderContentLength
               value:[NSString stringWithFormat:@"%ld", messageData.length]];
    [frame setBody:messageData];
    
    [self sendFrame:frame];
}

#pragma mark - Public - Subscriptions

- (id)subscribe:(NSString *)destination {
    
    NSString *identifier = [[NSUUID UUID] UUIDString];
    
    OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:OFFTStompFrameCommandSubscribe];
    [frame setHeader:OFFTStompHeaderDestination value:destination];
    [frame setHeader:OFFTStompHeaderID value:identifier];
    
    [self sendFrame:frame];
    
    return [[OFFTStompSubscription alloc] initWithIdentifier:identifier];
}

- (void)unsubscribe:(id)subscription {
    // Protection
    if ([subscription isKindOfClass:[OFFTStompSubscription class]] == NO) {
        NSAssert(0, @"You must provide an OFFTStompSubscription object.");
        return;
    }
    
    NSString *identifier = [(OFFTStompSubscription *)subscription identifier];
    
    OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:OFFTStompFrameCommandUnsubscribe];
    [frame setHeader:OFFTStompHeaderID value:identifier];
    
    [self sendFrame:frame];
}

#pragma mark - Transport Delegate

- (void)transportDidOpen:(id<OFFTStompTransportAdapter>)transport {
    
    // https://stomp.github.io/stomp-specification-1.2.html#CONNECT_or_STOMP_Frame
    // https://stomp.github.io/stomp-specification-1.1.html#CONNECT_or_STOMP_Frame
    
    // Construct the frame
    // 1.1 and 1.2 clients SHOULD continue to use the CONNECT command to remain backward compatible with STOMP 1.0 servers
    OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:OFFTStompFrameCommandConnect];
    
    [frame setHeader:OFFTStompHeaderAcceptVersion value:OFFTStompAcceptVersions];
    
    // TODO: This returns a bad connect ERROR from the server
    // Something to do with RabbitMQ
    [frame setHeader:OFFTStompHeaderHost value:[self.transport host]];
    
    // TODO: Heartbeat
    
    // TODO: Login & password
    
    [self sendFrame:frame];
}

- (void)transportDidClose:(id<OFFTStompTransportAdapter>)transport {
    
    // Wipe out the receipt handlers and reset the counter
    _receiptHandlers = nil;
    _receiptCounter = 0;
    
    self.state = OFFTStompStateDisconnected;
    [self.delegate stompClient:self didDisconnectWithError:nil];
}

- (void)transport:(id<OFFTStompTransportAdapter>)transport didReceiveMessage:(NSString *)message {
    NSLog(@"Received message: %@", message);
    
    OFFTStompFrame *frame = [self deserializeFrameFromString:message];
    
    if (self.state == OFFTStompStateConnecting) {
        // We're expecting either a CONNECTED frame...
        if (frame.command == OFFTStompFrameCommandConnected) {
            [self handleConnectedFrame:frame];
        }
        
        // or an ERROR
        else if (frame.command == OFFTStompFrameCommandError) {
            self.state = OFFTStompStateDisconnected;
            [self.delegate stompClient:self didDisconnectWithError:[NSError errorWithDomain:OFFTStompErrorDomain
                                                                                       code:OFFTStompConnectionError
                                                                                   userInfo:nil]];
        }
        
        // Do no further message processing
        return;
    }
    
    // Handle regular messages
    if (frame.command == OFFTStompFrameCommandMessage) {
        [self handleMessageFrame:frame];
    }
    // Handle receipt frames
    else if (frame.command == OFFTStompFrameCommandReceipt) {
        NSString *receipt = [frame valueForHeader:OFFTStompHeaderReceipt];
        OFFTStompReceiptHandler handler = _receiptHandlers[receipt];
        if (handler) {
            handler();
            [_receiptHandlers removeObjectForKey:receipt];
        }
    }
}

#pragma mark - Private

- (void)sendFrame:(OFFTStompFrame *)frame {
    if (self.state == OFFTStompStateDisconnecting
    && frame.command != OFFTStompFrameCommandDisconnect) {
        NSAssert(0, @"Cannot send frames while in the process of disconnecting");
        return;
    }
    
    NSData *serializedFrame = [self serializeFrame:frame];
    
#if OFFTSTOMPDEBUG
    NSLog(@"Sending message: %@", [[NSString alloc] initWithData:serializedFrame encoding:NSUTF8StringEncoding]);
#endif
    
    [self.transport sendData:serializedFrame];
}

- (void)sendFrame:(OFFTStompFrame *)frame withReceiptHandler:(OFFTStompReceiptHandler)receiptHandler {
    
    // Associate a receipt header with this frame before it is sent
    NSString *receipt = [NSString stringWithFormat:@"%lu", ++self.receiptCounter];
    [frame setHeader:OFFTStompHeaderReceipt value:receipt];
    
    // Track this receipt request
    self.receiptHandlers[receipt] = receiptHandler;
    
    [self sendFrame:frame];
}

- (void)forceDisconnect {
    [self.transport close];
}

#pragma mark - Private - Frame Handlers

- (void)handleConnectedFrame:(OFFTStompFrame *)frame {
    
    NSString *negotiatedVersion = [frame valueForHeader:OFFTStompHeaderVersion];
    if ([negotiatedVersion isEqualToString:@"1.2"]) {
        self.negotiatedVersion = OFFTStompVersion1_2;
    } else if ([negotiatedVersion isEqualToString:@"1.1"]) {
        self.negotiatedVersion = OFFTStompVersion1_1;
    } else {
        NSAssert(0, @"Somehow managed to negotiate to an unknown protocol version.");
    }
    
    self.state = OFFTStompStateConnected;
    [self.delegate stompClientDidConnect:self];
}

- (void)handleMessageFrame:(OFFTStompFrame *)frame {
    
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

- (NSString *)stringForCommand:(OFFTStompFrameCommand)command {
    switch (command) {
        case OFFTStompFrameCommandMessage:
            return @"MESSAGE";

        case OFFTStompFrameCommandSend:
            return @"SEND";
            
        case OFFTStompFrameCommandSubscribe:
            return @"SUBSCRIBE";
            
        case OFFTStompFrameCommandUnsubscribe:
            return @"UNSUBSCRIBE";
            
        case OFFTStompFrameCommandError:
            return @"ERROR";
            
        case OFFTStompFrameCommandReceipt:
            return @"RECEIPT";
            
        case OFFTStompFrameCommandConnect:
            return @"CONNECT";
            
        case OFFTStompFrameCommandConnected:
            return @"CONNECTED";
            
        case OFFTStompFrameCommandDisconnect:
            return @"DISCONNECT";
            
        default:
            return nil;
    }
}

- (OFFTStompFrameCommand)commandForString:(NSString *)commandString {
    if ([commandString isEqualToString:@"MESSAGE"]) {
        return OFFTStompFrameCommandMessage;
        
    } else if ([commandString isEqualToString:@"SEND"]) {
        return OFFTStompFrameCommandSend;
        
    } else if ([commandString isEqualToString:@"SUBSCRIBE"]) {
        return OFFTStompFrameCommandSubscribe;
        
    } else if ([commandString isEqualToString:@"UNSUBSCRIBE"]) {
        return OFFTStompFrameCommandUnsubscribe;
        
    } else if ([commandString isEqualToString:@"ERROR"]) {
        return OFFTStompFrameCommandError;
        
    } else if ([commandString isEqualToString:@"RECEIPT"]) {
        return OFFTStompFrameCommandReceipt;
        
    } else if ([commandString isEqualToString:@"CONNECT"]) {
        return OFFTStompFrameCommandConnect;
        
    } else if ([commandString isEqualToString:@"CONNECTED"]) {
        return OFFTStompFrameCommandConnected;
        
    } else if ([commandString isEqualToString:@"DISCONNECT"]) {
        return OFFTStompFrameCommandDisconnect;
        
    } else {
        return OFFTStompFrameCommandUnknown;
    }
}

#pragma mark - Private - Frame Conversion

- (NSData *)serializeFrame:(OFFTStompFrame *)frame {

    NSData *eol = nil;
    // STOMP 1.2 uses carriage return + line feed
    // http://stomp.github.io/stomp-specification-1.2.html#STOMP_Frames
    if (self.negotiatedVersion == OFFTStompVersion1_2) {
        eol = [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    }
    // STOMP 1.1 uses only line feed
    // http://stomp.github.io/stomp-specification-1.1.html#STOMP_Frames
    else if (self.negotiatedVersion == OFFTStompVersion1_1) {
        eol = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSData *nullByte = [@"\0" dataUsingEncoding:NSUTF8StringEncoding];
    
    // Start with the command
    NSString *command = [self stringForCommand:frame.command];
    NSMutableData *data = [NSMutableData dataWithData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendData:eol];
    
    // Append the headers, each followed with a newline
    NSDictionary *frameHeaders = [frame allHeaders];
    for (NSString *key in frameHeaders) {
        
        // TODO: escape colons
        // http://stomp.github.io/stomp-specification-1.1.html#Value_Encoding
        
        NSString *headerLine = [NSString stringWithFormat:@"%@:%@", key, frameHeaders[key]];
        [data appendData:[headerLine dataUsingEncoding:NSUTF8StringEncoding]];
        [data appendData:eol];
    }
    
    // End the headers with an additional newline
    [data appendData:eol];
    
    // Append the body data
    if (frame.body) {
        [data appendData:frame.body];
    }
    
    // End the frame with a NULL byte
    [data appendData:nullByte];
    
    return data;
}

- (OFFTStompFrame *)deserializeFrameFromString:(NSString *)frameString {
    NSArray *lines = [frameString componentsSeparatedByString:@"\n"];
    
    if (lines.count > 1) {
        
        OFFTStompFrameCommand command = [self commandForString:lines[0]];
        if (command != OFFTStompFrameCommandUnknown) {
            OFFTStompFrame *frame = [[OFFTStompFrame alloc] initWithCommand:command];
            
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
