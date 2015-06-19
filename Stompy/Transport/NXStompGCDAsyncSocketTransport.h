//
//  NXStompGCDAsyncSocketTransport.h
//  Stompy
//
//  Created by Steve Wilford on 19/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompTransportAdapter.h"

@interface NXStompGCDAsyncSocketTransport : NSObject <NXStompTransportAdapter>

+ (NXStompGCDAsyncSocketTransport *)transportWithHost:(NSString *)host
                                                 port:(uint16_t)port
                                    connectionTimeout:(NSTimeInterval)connectionTimeout;

@end
