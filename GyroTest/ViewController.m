//
//  ViewController.m
//  GyroTest
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import "GCDAsyncUdpSocket.h"
#import <CoreMotion/CoreMotion.h>

#import "ViewController.h"
#import "PacketHandler.h"
#import "hexd.h"

#define radtodeg(x) (x * 180.0 / M_PI)

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
    GCDAsyncUdpSocket *socket;
    CMMotionManager *motionManager;
    NSUInteger packetCounter;
    NSData *lastAddress;
    CMDeviceMotion *lastMotionData;
    float gyroFactor;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    packetCounter = 0;
    socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    NSError *error = nil;
    
    if(![socket bindToPort:26760 error:&error]) {
        NSLog(@"Error starting server (bind): %@", error);
        return;
    }
    if(![socket beginReceiving:&error]) {
        [socket close];
        NSLog(@"Error starting server (beginRecv): %@", error);
        return;
    }
    
    NSLog(@"UDP server started on address %@, port %hu", [socket localHost], [socket localPort]);
    
    
    gyroFactor = 8.0;
    
    motionManager = [[CMMotionManager alloc] init];
    [motionManager setDeviceMotionUpdateInterval:0.1];
    __weak id weakSelf = self;
    [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        [weakSelf handleMotionUpdate:motion withError:error];
    }];
}

- (void)handleMotionUpdate:(CMDeviceMotion * _Nullable)motionData withError:(NSError * _Nullable)error {
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
    
    float xDelta, yDelta, zDelta;
    if(lastMotionData) {
        xDelta = motionData.attitude.pitch - lastMotionData.attitude.pitch;
        yDelta = motionData.attitude.roll - lastMotionData.attitude.roll;
        zDelta = motionData.attitude.yaw - lastMotionData.attitude.yaw;
    } else {
        xDelta = motionData.attitude.pitch;
        yDelta = motionData.attitude.roll;
        zDelta = motionData.attitude.yaw;
    }
    xDelta = radtodeg(xDelta) * gyroFactor;
    yDelta = -radtodeg(yDelta) * gyroFactor;
    zDelta = -radtodeg(zDelta) * gyroFactor;
    
    *(uint32_t *)(outPtr) = *(uint32_t *)&yDelta;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&zDelta;
    outPtr += 4;
    *(uint32_t *)(outPtr) = *(uint32_t *)&xDelta;
    outPtr += 4;
    
    
    lastMotionData = motionData;
    
    [PacketHandler sendPacket:[NSData dataWithBytes:outputData length:sizeof(outputData)] toAddress:lastAddress fromSocket:socket];
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    lastAddress = address;
    
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


@end
