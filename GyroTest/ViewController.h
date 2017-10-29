//
//  ViewController.h
//  GyroTest
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GCDAsyncUdpSocket.h"

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate>

- (float)calculateRotationDelta:(double)radiansPerSec with:(NSTimeInterval)timeDelta;
- (void)handleGyroUpdate:(CMGyroData * _Nullable)data withError:(NSError * _Nullable)error;

@end

