//
//  StompyTests.m
//  StompyTests
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "OFFTStompClient.h"
#import "OFFTStompSocketRocketTransport.h"
#import "SRWebSocket.h"

@interface StompyTests : XCTestCase <OFFTStompClientDelegate>

@property (nonatomic, strong) OFFTStompClient *stomp;

@property (nonatomic, strong) XCTestExpectation *connectionExpectation;

@end

@implementation StompyTests

- (void)setUp {
    [super setUp];

    NSURL *webSocketURL = [NSURL URLWithString:@"http://localhost:8080/ws/websocket"];
    OFFTStompSocketRocketTransport *transport = [OFFTStompSocketRocketTransport transportWithURL:webSocketURL];
    self.stomp = [OFFTStompClient stompWithTransport:transport];
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

- (void)stompClientDidConnect:(OFFTStompClient *)stompClient {
    [self.connectionExpectation fulfill];
}

- (void)stompClientDisconnectedWithError:(NSError *)error {
    NSLog(@"%@", error);
}

@end
