//
//  StompyTests.m
//  StompyTests
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NXStompClient.h"
#import "NXStompSocketRocketTransport.h"
#import "SRWebSocket.h"

@interface StompyTests : XCTestCase <NXStompClientDelegate>

@property (nonatomic, strong) NXStompClient *stomp;

@property (nonatomic, strong) XCTestExpectation *connectionExpectation;

@end

@implementation StompyTests

- (void)setUp {
    [super setUp];

    NSURL *webSocketURL = [NSURL URLWithString:@"http://localhost:8080/ws/websocket"];
    NXStompSocketRocketTransport *transport = [NXStompSocketRocketTransport transportWithURL:webSocketURL];
    self.stomp = [NXStompClient stompWithTransport:transport];
    self.stomp.delegate = self;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConnection {

    self.connectionExpectation = [self expectationWithDescription:@"Socket connection"];
    
    [self.stomp connect];
    
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        NSLog(@"%@", self.stomp);
    }];
}

#pragma mark - Stomp Client Delegate

- (void)stompClientDidConnect:(NXStompClient *)stompClient {
    [self.connectionExpectation fulfill];
}

- (void)stompClientDisconnectedWithError:(NSError *)error {
    NSLog(@"%@", error);
}

@end
