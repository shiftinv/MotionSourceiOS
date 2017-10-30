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

- (void)handleMotionUpdate:(CMDeviceMotion * _Nullable)motionData withError:(NSError * _Nullable)error;

@end

