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

@optional
- (void)stompClient:(NXStompClient *)stompClient didDisconnectWithError:(NSError *)error;

@end

@class NXStompAbstractTransport;

@interface NXStompClient : NSObject

@property (nonatomic, weak) id<NXStompClientDelegate> delegate;

+ (instancetype)stompWithTransport:(NXStompAbstractTransport *)transport;

- (void)connect;

@end
