//
//  NXStompFrame.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompFrame.h"

// Headers
NSString * const NXStompHeaderContentLength = @"content-length";

@interface NXStompFrame ()
@property (nonatomic, assign) NXStompFrameCommand command;
@property (nonatomic, strong) NSMutableDictionary *headers;

@property (nonatomic, assign) BOOL mayHaveBody;
@property (nonatomic, copy) NSString *bodyString;
@property (nonatomic, copy) NSData *bodyData;

@end

@implementation NXStompFrame

- (instancetype)initWithCommand:(NXStompFrameCommand)command {
    self = [super init];
    if (self) {
        _command = command;
        
        // Only the SEND, MESSAGE, and ERROR frames can have a body. All other frames MUST NOT have a body.
        // https://stomp.github.io/stomp-specification-1.2.html#Body
        // https://stomp.github.io/stomp-specification-1.1.html#Value_Encoding
        switch (_command) {
            case NXStompFrameCommandSend:
            case NXStompFrameCommandMessage:
            case NXStompFrameCommandError:
                _mayHaveBody = YES;
                break;
            default:
                _mayHaveBody = NO;
                break;
        }
    }
    return self;
}

#pragma mark - Lazy Instantiation

- (NSMutableDictionary *)headers {
    if (_headers == nil) {
        _headers = [[NSMutableDictionary alloc] init];
    }
    return _headers;
}

#pragma mark - Public

- (void)setHeader:(NSString *)header value:(NSString *)value {
    self.headers[header] = [value copy];
}

- (NSDictionary *)allHeaders {
    return [self.headers copy];
}

- (void)setBodyString:(NSString *)body {
    if (_mayHaveBody) {
        self.bodyData = nil;
        self.bodyString = body;
        self.headers[NXStompHeaderContentLength] = @(body.length);
    } else {
        NSAssert(0, @"This type of frame cannot have a body");
    }
}

- (void)setBodyData:(NSData *)body {
    if (_mayHaveBody) {
        self.bodyString = nil;
        self.bodyData = body;
        self.headers[NXStompHeaderContentLength] = @(body.length);
    } else {
        NSAssert(0, @"This type of frame cannot have a body");
    }
}

@end