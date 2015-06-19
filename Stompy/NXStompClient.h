//
//  NXStompClient.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NXStompTransportAdapter.h"

@class NXStompClient;

extern NSString * const NXStompErrorDomain;

typedef NS_ENUM(NSUInteger, NXStompError) {
    NXStompConnectionError = 1,
};

@protocol NXStompClientDelegate <NSObject>

/**
 *  The STOMP client successfully established a connection with the server.
 *
 *  @param stompClient The STOMP client.
 */
- (void)stompClientDidConnect:(NXStompClient *)stompClient;

/**
 *  The connection to the STOMP server has ended.
 *
 *  @param stompClient The STOMP client.
 *  @param error       An error detailing why the connection ended, or nil if it the disconnection was expected.
 */
- (void)stompClient:(NXStompClient *)stompClient didDisconnectWithError:(NSError *)error;

@optional

/**
 *  A message has been received from the STOMP server.
 *
 *  The delegate should implement either
 *  this method, or the alternative:-
 *  stompClient:receivedMessageData:withHeaders
 *
 *  This method will NOT be called if both
 *  have been implemented.
 *
 *  @param stompClient The STOMP client.
 *  @param message     The body of the received message.
 *  @param headers     The headers of the received message.
 */
- (void)stompClient:(NXStompClient *)stompClient
    receivedMessage:(NSString *)message
        withHeaders:(NSDictionary *)headers;

/**
 *  A message has been received from the STOMP server.
 *
 *  The delegate should implement either
 *  this method, or the alternative:-
 *  stompClient:receivedMessage:withHeaders
 *
 *  This method will take precendence if both
 *  have been implemented.
 *
 *  @param stompClient The STOMP client.
 *  @param messageData The body of the received message.
 *  @param headers     The headers of the received message.
 */
- (void)stompClient:(NXStompClient *)stompClient
receivedMessageData:(NSData *)messageData
        withHeaders:(NSDictionary *)headers;

@end

@interface NXStompClient : NSObject

@property (nonatomic, weak) id<NXStompClientDelegate> delegate;

/**
 *  Creates a new STOMP client that will connect over the provided transport.
 *
 *  @param transport A transport adapter that will handle the sending & receiving of data.
 *
 *  @return A new NXStompClient instance
 */
+ (instancetype)stompWithTransport:(id<NXStompTransportAdapter>)transport;

- (void)connect;

- (void)disconnect;

#pragma mark - Sending messages

/**
 *  Sends a message to the provided destination.
 *
 *  @param message     The message to be sent.
 *  @param destination Where to send the message.
 */
- (void)sendMessage:(NSString *)message
      toDestination:(NSString *)destination;

/**
 *  Sends a message to the provided destination.
 *
 *  @param message     The message to be sent.
 *  @param destination Where to send the message.
 *  @param headers     User-defined headers as a dictionary of NSString : NSString objects.
 */
- (void)sendMessage:(NSString *)message
      toDestination:(NSString *)destination
  withCustomHeaders:(NSDictionary *)headers;

/**
 *  Sends a message to the provided destination.
 *  The data versions of sendMessage... are intended as helper
 *  methods for sending JSON or base64 data. They
 *  should not be used to send non-UTF8 encoded data.
 *
 *  @param message     The message to be sent. The data must represent a UTF8 encoded string.
 *  @param destination Where to send the message.
 */
- (void)sendMessageData:(NSData *)messageData
          toDestination:(NSString *)destination;

/**
 *  Sends a message to the provided destination.
 *  The data versions of sendMessage... are intended as helper
 *  methods for sending JSON or base64 data. They
 *  should not be used to send non-UTF8 encoded data.
 *
 *  @param message     The message to be sent. The data must represent a UTF8 encoded string.
 *  @param destination Where to send the message.
 *  @param headers     User-defined headers as a dictionary of NSString : NSString objects.
 */
- (void)sendMessageData:(NSData *)messageData
          toDestination:(NSString *)destination
      withCustomHeaders:(NSDictionary *)headers;

#pragma mark - Subscriptions

/**
 *  Subscribes to a given destination.
 *
 *  @param destination The destination of the subscription.
 *
 *  @return An opaque type that can be used to unsubscribe.
 */
- (id)subscribe:(NSString *)destination;

/**
 *  Unsubscribes from an existing subscription.
 *
 *  @param subscription The opaque subscription type provided by an earlier call to subscribe:
 */
- (void)unsubscribe:(id)subscription;

@end
