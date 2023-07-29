#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import <CoreMotion/CoreMotion.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

#import "ViewController.h"
#import "PacketHandler.h"

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
    bool accelerometerEnabled;
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
    
    accelerometerEnabled = true;
    [self setUpdatesPerSec:50];
    
    
    // ** UI **
    
    _connectionIndicator.layer.cornerRadius = _connectionIndicator.bounds.size.width / 2;
    
    [_ipAddressLabel setText:[self getIPAddress]];
    [_portTextField setText:[NSString stringWithFormat:@"%d", port]];
    [_portTextField setDelegate:self];
    [_startstopServerButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    [_startstopServerButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [_startstopServerButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateHighlighted];
    
    for(UIButton *button in _orientationButtons) {
        if(button.tag == 0) { // only runs for the first (portrait) button
            [self changeOrientation:button];
        }
        [button setBackgroundColor:[UIColor colorWithWhite:0.85f alpha:1.0f]];
        [button.layer setCornerRadius:12.0f];
        [button.layer setBorderColor:[[UIColor systemBlueColor] CGColor]];
    }
    
    NSString *versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionBuildString = [NSString stringWithFormat:@"v%@ (%@)", versionString, buildString];
    [_versionLabel setText:versionBuildString];
}


- (void)updateLastAddress:(NSData *)address {
    lastAddress = address;
    _connectionIndicator.backgroundColor = address ? [UIColor systemGreenColor] : [UIColor systemRedColor];
}


- (void)setUpdatesPerSec:(int)ups {
    [_updateIntervalSlider setValue:ups];
    [_updateIntervalTextField setText:[NSString stringWithFormat:@"%d", ups]];
    updatesPerSec = ups;
    if(motionManager)
        [motionManager setDeviceMotionUpdateInterval:(1.0 / updatesPerSec)];
}


- (void)startGyroUpdates {
    [self stopGyroUpdates];
    
    if(!motionManager) {
        motionManager = [[CMMotionManager alloc] init];
        [motionManager setDeviceMotionUpdateInterval:(1.0 / updatesPerSec)];
    }
    
    __weak id weakSelf = self;
    [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if(CACurrentMediaTime() > lastReceiveTime + (CLIENT_TIMEOUT_MS / 1000)) {
            NSLog(@"Client disconnected.");
            [weakSelf updateLastAddress:nil];
            [weakSelf stopGyroUpdates];
            return;
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
    [self updateLastAddress:nil];
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


- (void)displayInfoSheetWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:true completion:nil];
}


- (void)displayErrorWithMessage:(NSString *)message {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:controller animated:true completion:nil];
}


- (IBAction)enableAccelerometerSwitch:(UISwitch *)sender {
    accelerometerEnabled = sender.isOn;
}


- (IBAction)accelerometerInfoPressed:(UIButton *)sender {
    [self displayInfoSheetWithTitle:@"Accelerometer Usage" message:@"This generally helps counteract gyroscope drift. Some applications require accelerometer data to be provided."];
}


- (IBAction)aboutPressed:(id)sender {
    [self displayInfoSheetWithTitle:@"About" message:[NSString stringWithFormat:@"MotionSourceiOS %@\n\nSource code: https://github.com/shiftinv/MotionSourceiOS\n\nIcon courtesy of https://iconpacks.net", _versionLabel.text]];
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
    
    uint8_t outputData[84] = {0};
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
    
    uint64_t timestampUS = motionData.timestamp * pow(10, 6);
    *(uint64_t *)(outPtr) = timestampUS;
    outPtr += 8;
    
    CMAcceleration acc = motionData.userAcceleration;
    acc.x += motionData.gravity.x;
    acc.y += motionData.gravity.y;
    acc.z += motionData.gravity.z;
    CMRotationRate gyro = motionData.rotationRate;
    
    float accelX, accelY, accelZ;
    float gyroX, gyroY, gyroZ;
    switch(orientation) {
        case UIDeviceOrientationPortrait:
            accelX = acc.x;
            accelY = acc.z;
            accelZ = -acc.y;
            gyroX = gyro.x;
            gyroY = -gyro.z;
            gyroZ = gyro.y;
            break;
        case UIDeviceOrientationLandscapeRight:
            accelX = acc.y;
            accelY = acc.z;
            accelZ = acc.x;
            gyroX = gyro.y;
            gyroY = -gyro.z;
            gyroZ = -gyro.x;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            accelX = -acc.x;
            accelY = acc.z;
            accelZ = acc.y;
            gyroX = -gyro.x;
            gyroY = -gyro.z;
            gyroZ = -gyro.y;
            break;
        case UIDeviceOrientationLandscapeLeft:
            accelX = -acc.y;
            accelY = acc.z;
            accelZ = -acc.x;
            gyroX = -gyro.y;
            gyroY = -gyro.z;
            gyroZ = gyro.x;
            break;
        default:    // just to silence xcode warnings, this should never run
            return;
    }
    
    // accelerometer
    if (!accelerometerEnabled) {
        accelX = accelY = accelZ = 0;
    }
    
    *(uint32_t *)(outPtr) = *(uint32_t *)&accelX;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&accelY;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&accelZ;
    outPtr += 4;
    
    // gyro
    gyroX = radtodeg(gyroX);
    gyroY = radtodeg(gyroY);
    gyroZ = radtodeg(gyroZ);
    
    *(uint32_t *)(outPtr) = *(uint32_t *)&gyroX;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&gyroY;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&gyroZ;
    outPtr += 4;
    
    
    [PacketHandler sendPacket:[NSData dataWithBytes:outputData length:sizeof(outputData)] toAddress:lastAddress fromSocket:socket];
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    bool newClient = !lastAddress;
    [self updateLastAddress:address];
    lastReceiveTime = CACurrentMediaTime();
    if(newClient) {
        [self startGyroUpdates];
        
        NSString *client;
        uint16_t clientPort;
        [GCDAsyncUdpSocket getHost:&client port:&clientPort fromAddress:address];
        NSLog(@"New client: %@:%d", client, clientPort);
    }
    
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
