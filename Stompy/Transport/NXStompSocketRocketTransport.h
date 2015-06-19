//
//  NXStompSocketRocketTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompTransportAdapter.h"

@interface NXStompSocketRocketTransport : NSObject <NXStompTransportAdapter>

+ (NXStompSocketRocketTransport *)transportWithURL:(NSURL *)URL;

@end
