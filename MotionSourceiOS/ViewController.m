//
//  ViewController.m
//  MotionSourceiOS
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import <CoreMotion/CoreMotion.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

#import "ViewController.h"
#import "PacketHandler.h"
#import "hexd.h"

#define radtodeg(x) (x * 180.0 / M_PI)

#define CLIENT_TIMEOUT_MS 3000

typedef NS_ENUM(NSUInteger, MessageType)
{
    MessageTypeDSUCVersionReq = 0x100000,
    MessageTypeDSUSVersionRsp = 0x100000,
    MessageTypeDSUCListPorts = 0x100001,
    MessageTypeDSUSPortInfo = 0x100001,
    MessageTypeDSUCPadDataReq = 0x100002,
    MessageTypeDSUSPadDataRsp = 0x100002,
};


@interface ViewController () {
    // ** Networking **
    bool serverStarted;
    uint16_t port;
    NSUInteger packetCounter;
    NSData *lastAddress;
    NSTimeInterval lastReceiveTime;
    GCDAsyncUdpSocket *socket;
    
    // ** Gyroscope **
    CMMotionManager *motionManager;
    CMDeviceMotion *lastMotionData;
    float gyroSensitivity;
    int updatesPerSec;
    UIDeviceOrientation orientation;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ** Networking **
    
    serverStarted = false;
    port = 26760;
    packetCounter = 0;
    lastReceiveTime = 0;
    
    
    // ** Gyroscope **
    
    [self setGyroSensitivity:8];
    [self setUpdatesPerSec:10];
    
    
    // ** UI **
    [_ipAddressLabel setText:[self getIPAddress]];
    [_portTextField setText:[NSString stringWithFormat:@"%d", port]];
    [_portTextField setDelegate:self];
    [_startstopServerButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    [_startstopServerButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    for(UIButton *button in _orientationButtons) {
        if(button.tag == 0) { // only runs for the first (portrait) button
            [self changeOrientation:button];
        }
        [button setBackgroundColor:[UIColor colorWithWhite:0.85f alpha:1.0f]];
        [button.layer setCornerRadius:12.0f];
    }
}


- (void)setUpdatesPerSec:(int)ups {
    [_updateIntervalSlider setValue:ups];
    [_updateIntervalTextField setText:[NSString stringWithFormat:@"%d", ups]];
    updatesPerSec = ups;
    if(motionManager)
        [motionManager setDeviceMotionUpdateInterval:(1.0 / updatesPerSec)];
}

- (void)setGyroSensitivity:(int)sensitivity {
    [_sensitivitySlider setValue:sensitivity];
    [_sensitivityTextField setText:[NSString stringWithFormat:@"%d", sensitivity]];
    gyroSensitivity = sensitivity;
    NSLog(@"%d", sensitivity);
}


- (void)startGyroUpdates {
    if(!motionManager) {
        motionManager = [[CMMotionManager alloc] init];
        [motionManager setDeviceMotionUpdateInterval:(1.0 / updatesPerSec)];
    }
    
    __weak id weakSelf = self;
    [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if(CACurrentMediaTime() > lastReceiveTime + (CLIENT_TIMEOUT_MS / 1000)) {
            lastAddress = nil;
            [weakSelf stopGyroUpdates];
        }
        [weakSelf handleMotionUpdate:motion withError:error];
    }];
}

- (void)stopGyroUpdates {
    if(motionManager)
        [motionManager stopDeviceMotionUpdates];
}

- (void)startServer {
    if(serverStarted) {
        NSLog(@"Cannot start server because a server is already running. This should not happen.");
        return;
    }
    
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    
    if(![socket bindToPort:port error:&error]) {
        NSString *errorString = [NSString stringWithFormat:@"Error starting server (bind): %@", error];
        NSLog(@"%@", errorString);
        [self displayErrorWithMessage:errorString];
        
        return;
    }
    if(![socket beginReceiving:&error]) {
        [socket close];
        
        NSString *errorString = [NSString stringWithFormat:@"Error starting server (beginRecv): %@", error];
        NSLog(@"%@", errorString);
        [self displayErrorWithMessage:errorString];
        
        return;
    }
    
    [_startstopServerButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [_startstopServerButton setTitle:@"Stop Server" forState:UIControlStateNormal];
    NSLog(@"UDP server started on address %@, port %hu", [socket localHost], [socket localPort]);
    serverStarted = true;
}

- (void)stopServer {
    if(!serverStarted) {
        NSLog(@"Cannot stop server because it's not started. This should not happen.");
        return;
    }
    
    NSLog(@"Stopping server..");
    [socket close];
    [self stopGyroUpdates];
    [_startstopServerButton setEnabled:false];
    // button waits for delegate method udpSocketDidClose:withError: to be called
}

- (IBAction)startstopServer {
    if(serverStarted) {
        [self stopServer];
    } else {
        [self startServer];
    }
}

- (IBAction)setPortPressed:(id)sender {
    if([_portTextField hasText]
       && [[_portTextField text] intValue] >= 1024
       && [[_portTextField text] intValue] <= 65535) {
        int intValue = [[_portTextField text] intValue];
        port = intValue;
        
        [_startstopServerButton setEnabled:true];
        [self.view endEditing:true];
        [self stopServer];
    } else {
        NSString *errorMessage = [NSString stringWithFormat:@"The port must be in the range %d-%d", 1024, 65535];
        [self displayErrorWithMessage:errorMessage];
    }
}

// only updates textfield value
- (IBAction)intervalSliderChanged:(id)sender {
    int intValue = (int)_updateIntervalSlider.value;
    NSString *valueText = [NSString stringWithFormat:@"%d", intValue];
    [_updateIntervalTextField setText:valueText];
}

// updates textfield & slider values and changes update interval internally
- (IBAction)setIntervalPressed:(id)sender {
    if([_updateIntervalTextField hasText]
       && [[_updateIntervalTextField text] intValue] >= _updateIntervalSlider.minimumValue
       && [[_updateIntervalTextField text] intValue] <= _updateIntervalSlider.maximumValue) {
        int intValue = [[_updateIntervalTextField text] intValue];
        [self setUpdatesPerSec:intValue];
        [self.view endEditing:true];
    } else {
        NSString *errorMessage = [NSString stringWithFormat:@"The update interval must be in the range %d-%d", (int)_updateIntervalSlider.minimumValue, (int)_updateIntervalSlider.maximumValue];
        [self displayErrorWithMessage:errorMessage];
    }
}

- (IBAction)sensitivitySliderChanged:(id)sender {
    int intValue = (int)_sensitivitySlider.value;
    NSString *valueText = [NSString stringWithFormat:@"%d", intValue];
    [_sensitivityTextField setText:valueText];
}

- (IBAction)setSensitivityPressed:(id)sender {
    if([_sensitivityTextField hasText]
       && [[_sensitivityTextField text] intValue] >= _sensitivitySlider.minimumValue
       && [[_sensitivityTextField text] intValue] <= _sensitivitySlider.maximumValue) {
        int intValue = [[_sensitivityTextField text] intValue];
        [self setGyroSensitivity:intValue];
        [self.view endEditing:true];
    } else {
        NSString *errorMessage = [NSString stringWithFormat:@"The sensitivity must be in the range %d-%d", (int)_sensitivitySlider.minimumValue, (int)_sensitivitySlider.maximumValue];
        [self displayErrorWithMessage:errorMessage];
    }
}

- (IBAction)changeOrientation:(UIButton *)sender {
    for(UIButton *button in _orientationButtons) {
        if(button == sender)
            [button.layer setBorderWidth:3.0f];
        else
            [button.layer setBorderWidth:0.0f];
    }
    switch(sender.tag) {
        case 0:
            orientation = UIDeviceOrientationPortrait;
            break;
        case 1:
            orientation = UIDeviceOrientationLandscapeRight;
            break;
        case 2:
            orientation = UIDeviceOrientationPortraitUpsideDown;
            break;
        case 3:
            orientation = UIDeviceOrientationLandscapeLeft;
            break;
    }
}


- (void)displayErrorWithMessage:(NSString *)message {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:controller animated:true completion:nil];
}


- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [_startstopServerButton setEnabled:false];
}


- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    [_startstopServerButton setEnabled:true];
    [_startstopServerButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    [_startstopServerButton setTitle:@"Start Server" forState:UIControlStateNormal];
    NSLog(@"Stopped UDP server");
    socket = nil;
    serverStarted = false;
}

- (void)handleMotionUpdate:(CMDeviceMotion *)motionData withError:(NSError *)error {
    if(lastAddress == nil || error != nil)
        return;
    
    uint8_t outputData[84];
    uint8_t *outPtr = outputData;
    *(uint32_t *)(outPtr) = MessageTypeDSUSPadDataRsp;
    outPtr += 4;
    
    *outPtr = 0;  // PadId (0)
    outPtr++;
    *outPtr = 2;  // PadState (Connected)
    outPtr++;
    *outPtr = 2;  // Model (DS4)
    outPtr++;
    *outPtr = 2;  // ConnectionType (Bluetooth)
    outPtr++;
    
    *(uint16_t *)(outPtr) = 0xab12;
    outPtr += 2;
    *(uint16_t *)(outPtr) = 0xcd34;
    outPtr += 2;
    *(uint16_t *)(outPtr) = 0xef56;
    outPtr += 2;
    
    *outPtr = 5;  // BatteryStatus (Full)
    outPtr++;
    *outPtr = 1;
    outPtr++;
    
    *(uint32_t *)(outPtr) = (uint32_t)packetCounter++;
    outPtr += 4;
    
    *outPtr = 0;    // high nib: Dpad | low nib: Opt/Share/L3/R3
    outPtr++;
    *outPtr = 0;    // high nib: A/B/X/Y | low nib: L1/R1/L2/R2
    outPtr++;
    *outPtr = 0;    // PS
    outPtr++;
    *outPtr = 0;    // TouchButton
    outPtr++;
    
    *(uint16_t *)(outPtr) = 0;  // left stick
    outPtr += 2;
    *(uint16_t *)(outPtr) = 0;  // right stick
    outPtr += 2;
    *(uint32_t *)(outPtr) = 0;  // Dpad
    outPtr += 4;
    *(uint32_t *)(outPtr) = 0;  // A/B/X/Y
    outPtr += 4;
    *(uint32_t *)(outPtr) = 0;  // L1/R1/L2/R2
    outPtr += 4;
    
    memset(outPtr, 0, 12); // touchpad
    outPtr += 12;
    
    NSUInteger timestampUS = motionData.timestamp * pow(10, 6);
    *(uint64_t *)(outPtr) = timestampUS;
    outPtr += 8;
    
    memset(outPtr, 0, 12); // accelerometer
    outPtr += 12;
    
    float pitchDelta, rollDelta, yawDelta;
    if(lastMotionData) {
        pitchDelta = motionData.attitude.pitch - lastMotionData.attitude.pitch;
        rollDelta = motionData.attitude.roll - lastMotionData.attitude.roll;
        yawDelta = motionData.attitude.yaw - lastMotionData.attitude.yaw;
    } else {
        pitchDelta = motionData.attitude.pitch;
        rollDelta = motionData.attitude.roll;
        yawDelta = motionData.attitude.yaw;
    }
    pitchDelta = radtodeg(pitchDelta) * gyroSensitivity;
    rollDelta = radtodeg(rollDelta) * gyroSensitivity;
    yawDelta = radtodeg(yawDelta) * gyroSensitivity;
    
    float xDelta, yDelta, zDelta;
    switch(orientation) {
        case UIDeviceOrientationPortrait:
            xDelta = pitchDelta;
            yDelta = -yawDelta;
            zDelta = rollDelta;
            break;
        case UIDeviceOrientationLandscapeRight:
            xDelta = rollDelta;
            yDelta = -yawDelta;
            zDelta = -pitchDelta;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            xDelta = -pitchDelta;
            yDelta = -yawDelta;
            zDelta = -rollDelta;
            break;
        case UIDeviceOrientationLandscapeLeft:
            xDelta = -rollDelta;
            yDelta = -yawDelta;
            zDelta = pitchDelta;
            break;
        default:    // just to silence xcode warnings, this should never run
            return;
    }
    
    *(uint32_t *)(outPtr) = *(uint32_t *)&xDelta;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&yDelta;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&zDelta;
    outPtr += 4;
    
    
    lastMotionData = motionData;
    
    [PacketHandler sendPacket:[NSData dataWithBytes:outputData length:sizeof(outputData)] toAddress:lastAddress fromSocket:socket];
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    bool newClient = false;
    if(!lastAddress)
        newClient = true;
    lastAddress = address;
    lastReceiveTime = CACurrentMediaTime();
    if(newClient)
        [self startGyroUpdates];
    
    //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    //hexd(data);
    const unsigned char *bufPtr = [data bytes];
    
    if(strncmp((const char *)bufPtr, "DSUC", 4) != 0)
        return;
    bufPtr += 4;
    
    uint16_t protocolVer = *(uint16_t *)(bufPtr);
    bufPtr += 2;
    
    uint16_t packetSize = *(uint16_t *)(bufPtr);
    bufPtr += 2;
    
    uint32_t crcValue = *(uint32_t *)(bufPtr); //TODO: verify crc
    bufPtr += 4;
    
    uint32_t clientID = *(uint32_t *)(bufPtr);
    bufPtr += 4;
    
    MessageType messageType = *(uint32_t *)(bufPtr);
    bufPtr += 4;
    
    if(messageType == MessageTypeDSUCVersionReq) {
        //NSLog(@"messageType: DSUC_VersionReq");
        
        uint8_t outputData[8];
        uint8_t *outPtr = outputData;
        *(uint32_t *)(outPtr) = MessageTypeDSUSVersionRsp;
        outPtr += 4;
        *(uint16_t *)(outPtr) = (uint16_t)1001;
        outPtr += 2;
        *(uint16_t *)(outPtr) = (uint16_t)0;
        outPtr += 2;
        
        [PacketHandler sendPacket:[NSData dataWithBytes:outputData length:sizeof(outputData)] toAddress:address fromSocket:socket];
    } else if(messageType == MessageTypeDSUCListPorts) {
        //NSLog(@"messageType: DSUC_ListPorts");
        
        int numPadRequests = *(uint32_t *)(bufPtr);
        bufPtr += 4;
        
        uint8_t outputData[16];
        uint8_t *outPtr = outputData;
        *(uint32_t *)(outPtr) = MessageTypeDSUSPortInfo;
        outPtr += 4;
        
        *outPtr = 0;  // PadId (0)
        outPtr++;
        *outPtr = 2;  // PadState (Connected)
        outPtr++;
        *outPtr = 2;  // Model (DS4)
        outPtr++;
        *outPtr = 2;  // ConnectionType (Bluetooth)
        outPtr++;
        
        *(uint16_t *)(outPtr) = 0xab12;
        outPtr += 2;
        *(uint16_t *)(outPtr) = 0xcd34;
        outPtr += 2;
        *(uint16_t *)(outPtr) = 0xef56;
        outPtr += 2;
        
        *outPtr = 5;  // BatteryStatus (Full)
        outPtr++;
        *outPtr = 0;
        outPtr++;
        
        [PacketHandler sendPacket:[NSData dataWithBytes:outputData length:sizeof(outputData)] toAddress:address fromSocket:socket];
        
        /**(uint32_t *)(outputData)    = 0x00100001;
         *(uint32_t *)(outputData+4)  = 0x00000001;
         *(uint32_t *)(outputData+8)  = 0x00000000;
         *(uint32_t *)(outputData+12) = 0x00000000;
         sendPacket(udp.remoteIP(), udp.remotePort(), outputData, sizeof(outputData));
         *(uint32_t *)(outputData)    = 0x00100001;
         *(uint32_t *)(outputData+4)  = 0x00000002;
         *(uint32_t *)(outputData+8)  = 0x00000000;
         *(uint32_t *)(outputData+12) = 0x00000000;
         sendPacket(udp.remoteIP(), udp.remotePort(), outputData, sizeof(outputData));
         *(uint32_t *)(outputData)    = 0x00100001;
         *(uint32_t *)(outputData+4)  = 0x00000003;
         *(uint32_t *)(outputData+8)  = 0x00000000;
         *(uint32_t *)(outputData+12) = 0x00000000;
         sendPacket(udp.remoteIP(), udp.remotePort(), outputData, sizeof(outputData));*/
    } else if(messageType == MessageTypeDSUCPadDataReq) {
        //NSLog(@"messageType: DSUC_PadDataReq");
        
        uint8_t regFlags = *bufPtr;
        bufPtr++;
        uint8_t idToReg = *bufPtr;
        bufPtr++;
        
        /*CMGyroData *gyroData = motionManager.gyroData;
        if(gyroData != nil)
            [self handleGyroUpdate:gyroData withError:nil];*/
    }
}

- (NSString *)getIPAddress {
    NSString *address = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}


@end
