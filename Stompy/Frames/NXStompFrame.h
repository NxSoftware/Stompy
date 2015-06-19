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
    NXStompFrameCommandConnect,     // out
    NXStompFrameCommandConnected,   // in
    NXStompFrameCommandDisconnect,  // out
    NXStompFrameCommandSend,        // out
    NXStompFrameCommandSubscribe,   // out
    NXStompFrameCommandUnsubscribe, // out
    NXStompFrameCommandMessage,     // in
    NXStompFrameCommandError,       // in
    NXStompFrameCommandReceipt,     // in
};

@interface NXStompFrame : NSObject

/**
 *  Indicates whether or not the receiving frame may have a body.
 */
@property (nonatomic, assign, readonly) BOOL mayHaveBody;

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
 * Retrieves the value of the provided header, or nil if the header does not exist.
 */
- (NSString *)valueForHeader:(NSString *)header;

/**
 * Retrieves all headers
 */
- (NSDictionary *)allHeaders;

/**
 * Sets the body of the receiving frame with the provided data
 */
- (void)setBody:(NSData *)body;

/**
 * Retrieves the body, nil if no body.
 */
- (NSData *)body;

@end
