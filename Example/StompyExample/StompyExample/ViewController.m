//
//  ViewController.m
//  StompyExample
//
//  Created by Steve Wilford on 18/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "ViewController.h"
#import <Stompy/Stompy.h>

@interface ViewController () <OFFTStompClientDelegate>

@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;
@property (weak, nonatomic) IBOutlet UIButton *subscribeButton;
@property (weak, nonatomic) IBOutlet UIButton *unsubscribeButton;

@property (nonatomic, strong) OFFTStompClient *stomp;
@property (nonatomic, strong) id stompSubscription;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.disconnectButton.enabled = NO;
    self.subscribeButton.enabled = NO;
    self.unsubscribeButton.enabled = NO;
    
    id<OFFTStompTransportAdapter> transport = nil;
    
    BOOL useSpring = YES;
    if (useSpring) {
        NSURL *webSocketURL = [NSURL URLWithString:@"http://localhost:8080/ws/websocket"];
        transport = [OFFTStompSocketRocketTransport transportWithURL:webSocketURL];
    } else {
        transport = [OFFTStompGCDAsyncSocketTransport transportWithHost:@"localhost"
                                                                 port:61613
                                                    connectionTimeout:10];
    }
    
    self.stomp = [OFFTStompClient stompWithTransport:transport];
    self.stomp.delegate = self;
}

#pragma mark - IBActions

- (IBAction)connect:(id)sender {
    self.connectButton.enabled = NO;
    [self.stomp connect];
}

- (IBAction)disconnect:(id)sender {
    self.connectButton.enabled = NO;
    self.disconnectButton.enabled = NO;
    [self.stomp disconnect];
}

- (IBAction)subscribeButtonTapped:(id)sender {
    self.stompSubscription = [self.stomp subscribe:@"/topic/greetings"];
    self.subscribeButton.enabled = NO;
    self.unsubscribeButton.enabled = YES;
}

- (IBAction)unsubscribeButtonTapped:(id)sender {
    [self.stomp unsubscribe:self.stompSubscription];
    self.subscribeButton.enabled = YES;
    self.unsubscribeButton.enabled = NO;
}

- (IBAction)sendButtonTapped:(id)sender {
    
    NSData *message = [NSJSONSerialization dataWithJSONObject:@{@"name" : @"steve"}
                                                      options:0
                                                        error:nil];
    
    [self.stomp sendMessageData:message toDestination:@"/app/hello"];
}

#pragma mark - Stomp Delegate

- (void)stompClientDidConnect:(OFFTStompClient *)stompClient {
    NSLog(@"DID CONNECT");
    self.disconnectButton.enabled = YES;
    self.subscribeButton.enabled = YES;
    self.unsubscribeButton.enabled = NO;
}

- (void)stompClient:(OFFTStompClient *)stompClient
receivedMessageData:(NSData *)message
        withHeaders:(NSDictionary *)headers {
    NSLog(@"Received message: %@", message);
    
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:message
                                                options:0
                                                  error:&error];
    
    if (error) {
        NSLog(@"%@", error);
    } else {
        NSLog(@"%@", object);
    }
    
}

- (void)stompClient:(OFFTStompClient *)stompClient didDisconnectWithError:(NSError *)error {
    NSLog(@"DISCONNECTED %@", error);
    self.connectButton.enabled = YES;
    self.disconnectButton.enabled = NO;
    self.subscribeButton.enabled = NO;
    self.unsubscribeButton.enabled = NO;
}

@end
