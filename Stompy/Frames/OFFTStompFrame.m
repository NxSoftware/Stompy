//
//  OFFTStompFrame.m
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompFrame.h"

@interface OFFTStompFrame ()
@property (nonatomic, assign) OFFTStompFrameCommand command;
@property (nonatomic, strong) NSMutableDictionary *headers;

@property (nonatomic, assign) BOOL mayHaveBody;
@property (nonatomic, copy) NSData *body;

@end

@implementation OFFTStompFrame

- (instancetype)initWithCommand:(OFFTStompFrameCommand)command {
    self = [super init];
    if (self) {
        _command = command;
        
        // Only the SEND, MESSAGE, and ERROR frames can have a body. All other frames MUST NOT have a body.
        // https://stomp.github.io/stomp-specification-1.2.html#Body
        // https://stomp.github.io/stomp-specification-1.1.html#Value_Encoding
        switch (_command) {
            case OFFTStompFrameCommandSend:
            case OFFTStompFrameCommandMessage:
            case OFFTStompFrameCommandError:
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

- (NSString *)valueForHeader:(NSString *)header {
    return _headers[header];
}

- (NSDictionary *)allHeaders {
    return [_headers copy];
}

- (void)setBody:(NSData *)body {
    if (_mayHaveBody) {
        _body = [body copy];
    } else {
        NSAssert(0, @"This type of frame cannot have a body");
    }
}

@end
