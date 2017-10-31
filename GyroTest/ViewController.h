//
//  ViewController.h
//  GyroTest
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GCDAsyncUdpSocket.h"

@interface ViewController : UIViewController <GCDAsyncUdpSocketDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *portTextField;
@property (weak, nonatomic) IBOutlet UIButton *startstopServerButton;
@property (weak, nonatomic) IBOutlet UISlider *updateIntervalSlider;
@property (weak, nonatomic) IBOutlet UITextField *updateIntervalTextField;

- (void)startServer;
- (void)stopServer;
- (IBAction)startstopServer;
- (IBAction)setPortPressed:(id)sender;
- (IBAction)updateIntervalChanged:(id)sender;
- (IBAction)setIntervalPressed:(id)sender;
- (void)displayErrorWithMessage:(NSString *)message;
- (void)handleMotionUpdate:(CMDeviceMotion *)motionData withError:(NSError *)error;

@end

