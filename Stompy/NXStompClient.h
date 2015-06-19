//
//  NXStompClient.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NXStompClient;

extern NSString * const NXStompErrorDomain;

typedef NS_ENUM(NSUInteger, NXStompError) {
    NXStompConnectionError = 1,
};

@protocol NXStompClientDelegate <NSObject>
- (void)stompClientDidConnect:(NXStompClient *)stompClient;

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

@class NXStompAbstractTransport;

@interface NXStompClient : NSObject

@property (nonatomic, weak) id<NXStompClientDelegate> delegate;

+ (instancetype)stompWithTransport:(NXStompAbstractTransport *)transport;

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
 *
 *  @param message     The message to be sent. The data must represent a UTF8 encoded string.
 *  @param destination Where to send the message.
 */
- (void)sendMessageData:(NSData *)messageData
          toDestination:(NSString *)destination;

/**
 *  Sends a message to the provided destination.
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
