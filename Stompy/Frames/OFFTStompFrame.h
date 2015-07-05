//
//  OFFTStompFrame.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

// Frame commands
typedef NS_ENUM(NSUInteger, OFFTStompFrameCommand) {
    OFFTStompFrameCommandUnknown,
    OFFTStompFrameCommandConnect,     // out
    OFFTStompFrameCommandConnected,   // in
    OFFTStompFrameCommandDisconnect,  // out
    OFFTStompFrameCommandSend,        // out
    OFFTStompFrameCommandSubscribe,   // out
    OFFTStompFrameCommandUnsubscribe, // out
    OFFTStompFrameCommandMessage,     // in
    OFFTStompFrameCommandError,       // in
    OFFTStompFrameCommandReceipt,     // in
};

@interface OFFTStompFrame : NSObject

/**
 *  Indicates whether or not the receiving frame may have a body.
 */
@property (nonatomic, assign, readonly) BOOL mayHaveBody;

/**
 * Initialises a STOMP frame for the specified command
 */
- (instancetype)initWithCommand:(OFFTStompFrameCommand)command NS_DESIGNATED_INITIALIZER;

/**
 * Retrieves the command.
 */
- (OFFTStompFrameCommand)command;

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
