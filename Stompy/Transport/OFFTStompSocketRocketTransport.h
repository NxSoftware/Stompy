//
//  OFFTStompSocketRocketTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompTransportAdapter.h"

@interface OFFTStompSocketRocketTransport : NSObject <OFFTStompTransportAdapter>

+ (OFFTStompSocketRocketTransport *)transportWithURL:(NSURL *)URL;

+ (OFFTStompSocketRocketTransport *)transportWithURLRequest:(NSURLRequest *)request;

@end
