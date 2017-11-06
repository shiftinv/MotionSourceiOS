//
//  PacketHandler.m
//  MotionSourceiOS
//
//  Created on 28.10.17.
//  Copyright © 2017 All rights reserved.
//

#import <Foundation/Foundation.h>
#import <zlib.h>

#import "PacketHandler.h"
#import "hexd.h"

#define SERVERID 53473400


@implementation PacketHandler

+ (void)sendPacket:(NSData *)data toAddress:(NSData *)address fromSocket:(GCDAsyncUdpSocket *)socket {
    hexd(data);
    NSUInteger capacity = 16 + data.length;
    NSMutableData *packet = [NSMutableData dataWithCapacity:capacity];
    
    hexd(packet);
    [self beginPacket:packet withDataLength:capacity];
    hexd(packet);
    [packet appendData:data];
    hexd(packet);
    [self finishPacket:packet];
    hexd(packet);
    
    [socket sendData:packet toAddress:address withTimeout:-1 tag:0];
}

+ (void)beginPacket:(NSMutableData *)packet withDataLength:(NSUInteger)length {
    unsigned char packetBuf[16];
    int currIndex = 0;
    
    memcpy(packetBuf, "DSUS", 4);
    currIndex += 4;
    
    *(uint16_t *)(packetBuf + currIndex) = (uint16_t)1001;
    currIndex += 2;
    
    *(uint16_t *)(packetBuf + currIndex) = (uint16_t)(length - 16);
    currIndex += 2;
    
    memset(packetBuf + currIndex, 0, 4);
    currIndex += 4;
    
    *(uint32_t *)(packetBuf + currIndex) = (uint32_t)SERVERID;
    currIndex += 4;
    
    [packet appendBytes:packetBuf length:sizeof(packetBuf)];
}

+ (void)finishPacket:(NSMutableData *)packet {
    unsigned long crc = crc32(0, [packet bytes], (uInt)packet.length);
    [packet replaceBytesInRange:NSMakeRange(8, 4) withBytes:&crc];
}

@end
