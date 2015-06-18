//
//  NXStompFrame.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

// Frame commands
typedef NS_ENUM(NSUInteger, NXStompFrameCommand) {
    NXStompFrameCommandUnknown,
    NXStompFrameCommandConnect,
    NXStompFrameCommandConnected, // incoming only
    NXStompFrameCommandSend,
    NXStompFrameCommandMessage, // incoming only?
    NXStompFrameCommandError, // incoming only?
};

@interface NXStompFrame : NSObject

/**
 * Initialises a STOMP frame for the specified command
 */
- (instancetype)initWithCommand:(NXStompFrameCommand)command NS_DESIGNATED_INITIALIZER;

/**
 * Retrieves the command.
 */
- (NXStompFrameCommand)command;

/**
 * Sets the header with the provided value
 */
- (void)setHeader:(NSString *)header value:(NSString *)value;

/**
 * Retrieves all headers
 */
- (NSDictionary *)allHeaders;

/**
 * Sets the body of the receiving frame with the provided string
 */
- (void)setBodyString:(NSString *)body;

/**
 * Retrieves the body as a string, nil if no body or body is data.
 */
- (NSString *)bodyString;

/**
 * Sets the body of the receiving frame with the provided data
 */
- (void)setBodyData:(NSData *)body;

/**
 * Retrieves the body as data, nil if no body or body is a string.
 */
- (NSData *)bodyData;

@end
