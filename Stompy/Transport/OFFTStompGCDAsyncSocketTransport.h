//
//  OFFTStompGCDAsyncSocketTransport.h
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "OFFTStompTransportAdapter.h"

@interface OFFTStompGCDAsyncSocketTransport : NSObject <OFFTStompTransportAdapter>

+ (OFFTStompGCDAsyncSocketTransport *)transportWithHost:(NSString *)host
                                                 port:(uint16_t)port
                                    connectionTimeout:(NSTimeInterval)connectionTimeout;

@end
