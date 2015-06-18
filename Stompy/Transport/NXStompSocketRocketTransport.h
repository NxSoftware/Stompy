//
//  NXStompSocketRocketTransport.h
//  Stompy
//
//  Created by Steve Wilford on 17/06/2015.
//  Copyright (c) 2015 Steve Wilford. All rights reserved.
//

#import "NXStompAbstractTransport.h"

@interface NXStompSocketRocketTransport : NXStompAbstractTransport

+ (NXStompSocketRocketTransport *)transportWithURL:(NSURL *)URL;

@end
