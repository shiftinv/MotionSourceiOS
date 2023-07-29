#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

@interface PacketHandler : NSObject

+ (void)sendPacket:(NSData *)data toAddress:(NSData *)address fromSocket:(GCDAsyncUdpSocket *)socket;
+ (void)beginPacket:(NSMutableData *)packet withDataLength:(NSUInteger)length;
+ (void)finishPacket:(NSMutableData *)packet;

@end
