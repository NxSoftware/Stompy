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
NSString * const NXStompHeaderHost = @"host";

typedef NS_OPTIONS(NSUInteger, NXStompVersion) {
    NXStompVersion1_1 = 1 << 1,
    NXStompVersion1_2 = 1 << 2,
};

typedef NS_ENUM(NSUInteger, NXStompState) {
    NXStompStateDisconnected,
    NXStompStateConnecting,
    NXStompStateConnected,
};

@interface NXStompClient () <NXStompTransportDelegate>
@property (nonatomic, strong, nonnull) NXStompAbstractTransport *transport;
@property (nonatomic, copy) NSString *host;

/**
 * The versions of the STOMP protocol to use. Defaults to 1.2
 */
@property (nonatomic, assign) NXStompVersion supportedVersions;

@property (nonatomic, assign) NXStompState state;

@end

@implementation NXStompClient

+ (instancetype)stompWithTransport:(NXStompAbstractTransport *)transport {
    
    NXStompClient *client = [[self alloc] init];
    client.transport = transport;
    client.transport.delegate = client;
    return client;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _supportedVersions = NXStompVersion1_1 | NXStompVersion1_2;
    }
    return self;
}

#pragma mark - Public

- (void)connect {
    self.state = NXStompStateConnecting;
    [self.transport connect];
}

#pragma mark - Transport Delegate

- (void)transportDidConnect:(NXStompAbstractTransport *)transport {
    
    // https://stomp.github.io/stomp-specification-1.2.html#CONNECT_or_STOMP_Frame
    // https://stomp.github.io/stomp-specification-1.1.html#CONNECT_or_STOMP_Frame
    
    // Construct the frame
    // 1.1 and 1.2 clients SHOULD continue to use the CONNECT command to remain backward compatible with STOMP 1.0 servers
    NXStompFrame *frame = [[NXStompFrame alloc] initWithCommand:NXStompFrameCommandConnect];
    
    NSMutableArray *acceptVersions = [[NSMutableArray alloc] initWithCapacity:2];
    
    if (self.supportedVersions & NXStompVersion1_1) {
        [acceptVersions addObject:@"1.2"];
    }
    if (self.supportedVersions & NXStompVersion1_2) {
        [acceptVersions addObject:@"1.3"];
    }
    
    if ([acceptVersions count]) {
        [frame setHeader:NXStompHeaderAcceptVersion
                   value:[acceptVersions componentsJoinedByString:@","]];
    }
    
    // TODO: This returns a bad connect ERROR from the server - investigate
    [frame setHeader:NXStompHeaderHost value:[self.transport host]];
    
    // TODO: Heartbeat
    
    // TODO: Login & password
    
    NSData *serializedFrame = [self serializeFrame:frame];
    
    [self.transport sendData:serializedFrame];
}

- (void)transport:(NXStompAbstractTransport *)transport didReceiveMessage:(NSString *)message {
    NSLog(@"Received message: %@", message);
    
    NXStompFrame *frame = [self deserializeFrameFromString:message];
    
    if (self.state == NXStompStateConnecting) {
        // We're expecting either a CONNECTED frame...
        if (frame.command == NXStompFrameCommandConnected) {
            self.state = NXStompStateConnected;
            [self.delegate stompClientDidConnect:self];
        }
        
        // or an ERROR
        else if (frame.command == NXStompFrameCommandError) {
            self.state = NXStompStateDisconnected;
            [self.delegate stompClient:self didDisconnectWithError:[NSError errorWithDomain:NXStompErrorDomain
                                                                                       code:1
                                                                                   userInfo:nil]];
        }
    }
    
}

#pragma mark - Private

- (NSString *)stringForCommand:(NXStompFrameCommand)command {
    switch (command) {
        case NXStompFrameCommandMessage:
            return @"MESSAGE";
            
        case NXStompFrameCommandSend:
            return @"SEND";
            
        case NXStompFrameCommandError:
            return @"ERROR";
            
        case NXStompFrameCommandConnect:
            return @"CONNECT";
            
        case NXStompFrameCommandConnected:
            return @"CONNECTED";
            
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
    } else if ([commandString isEqualToString:@"CONNECT"]) {
        return NXStompFrameCommandConnect;
    } else if ([commandString isEqualToString:@"CONNECTED"]) {
        return NXStompFrameCommandConnected;
    } else {
        return NXStompFrameCommandUnknown;
    }
}

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

@end
