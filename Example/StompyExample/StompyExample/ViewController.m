//
//  ViewController.m
//  StompyExample
//
//  Created by Steve Wilford on 18/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "ViewController.h"
#import <Stompy/Stompy.h>

@interface ViewController () <NXStompClientDelegate>

@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *disconnectButton;

@property (nonatomic, strong) NXStompClient *stomp;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.disconnectButton.enabled = NO;
    
    NSURL *webSocketURL = [NSURL URLWithString:@"http://localhost:8080/ws/websocket"];
    NXStompSocketRocketTransport *transport = [NXStompSocketRocketTransport transportWithURL:webSocketURL];
    self.stomp = [NXStompClient stompWithTransport:transport];
    self.stomp.delegate = self;
}

- (IBAction)connect:(id)sender {
    self.connectButton.enabled = NO;
    [self.stomp connect];
}

- (IBAction)disconnect:(id)sender {
    self.connectButton.enabled = NO;
    self.disconnectButton.enabled = NO;
    [self.stomp disconnect];
}

#pragma mark - Stomp Delegate

- (void)stompClientDidConnect:(NXStompClient *)stompClient {
    NSLog(@"DID CONNECT");
    self.disconnectButton.enabled = YES;
}

- (void)stompClient:(NXStompClient *)stompClient didDisconnectWithError:(NSError *)error {
    NSLog(@"DISCONNECTED %@", error);
    self.connectButton.enabled = YES;
    self.disconnectButton.enabled = NO;
}

@end
