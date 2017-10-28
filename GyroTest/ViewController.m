//
//  ViewController.m
//  GyroTest
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import "GCDAsyncUdpSocket.h"

#import "ViewController.h"
#import "PacketHandler.h"


enum MessageType
{
    MessageType_DSUC_VersionReq = 0x100000,
    MessageType_DSUS_VersionRsp = 0x100000,
    MessageType_DSUC_ListPorts = 0x100001,
    MessageType_DSUS_PortInfo = 0x100001,
    MessageType_DSUC_PadDataReq = 0x100002,
    MessageType_DSUS_PadDataRsp = 0x100002,
};

void hexd(NSData* data);


@interface ViewController () {
    GCDAsyncUdpSocket *socket;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
}


- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    hexd(data);
    const char *bufPtr = [data bytes];
    
    if(strncmp(bufPtr, "DSUC", 4) != 0)
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
    NSLog(@"%hd", protocolVer);
    uint32_t messageType = *(uint32_t *)(bufPtr);
    bufPtr += 4;
    
    if(messageType == MessageType_DSUC_VersionReq) {
        NSLog(@"messageType: DSUC_VersionReq");
        
        uint8_t outputData[8];
        uint8_t *outPtr = outputData;
        *(uint32_t *)(outPtr) = MessageType_DSUS_VersionRsp;
        outPtr += 4;
        *(uint16_t *)(outPtr) = (uint16_t)1001;
        outPtr += 2;
        *(uint16_t *)(outPtr) = (uint16_t)0;
        outPtr += 2;
        
        [PacketHandler sendPacket:[NSData dataWithBytesNoCopy:outputData length:sizeof(outputData) freeWhenDone:false] toAddress:address];
    } else if(messageType == MessageType_DSUC_ListPorts) {
        NSLog(@"messageType: DSUC_ListPorts");
        
        int numPadRequests = *(uint32_t *)(bufPtr);
        bufPtr += 4;
        
        uint8_t outputData[16];
        uint8_t *outPtr = outputData;
        *(uint32_t *)(outPtr) = MessageType_DSUS_PortInfo;
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
        
        [PacketHandler sendPacket:[NSData dataWithBytesNoCopy:outputData length:sizeof(outputData) freeWhenDone:false] toAddress:address];
        
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
    } else if(messageType == MessageType_DSUC_PadDataReq) {
        NSLog(@"messageType: DSUC_PadDataReq");
        
        uint8_t regFlags = *bufPtr;
        bufPtr++;
        uint8_t idToReg = *bufPtr;
        bufPtr++;
        
        //sendControllerReport();
    }
}


@end

void hexd(NSData* data) {
    uint64_t len = [data length];
    const char *buf = [data bytes];
    for (int i=0; i<len; i+=16) {
        printf("%06x: ", i);
        for (int j=0; j<16; j++)
            if (i+j < len)
                printf("%02x ", buf[i+j]);
            else
                printf("   ");
        printf(" ");
        for (int j=0; j<16; j++)
            if (i+j < len)
                printf("%c", isprint(buf[i+j]) ? buf[i+j] : '.');
        printf("\n");
    }
}
