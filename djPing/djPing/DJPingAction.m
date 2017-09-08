//
//  DJPingAction.m
//  SGVSDK
//
//  Created by dengjian on 2017/3/10.
//  Copyright © 2017年 dengjian. All rights reserved.
//

#import "DJPingAction.h"
#import "DJSimplePing.h"

@implementation DJPingItem

-(NSString *)description{
    NSString * desc = @"";
    switch (self.status) {
        case 1:{
            desc = [NSString stringWithFormat:@"%ld byte from %@: icmp_seq=%ld time=%.3f ms",
                    (long)self.dataByteLenth,
                    self.host,
                    (long)self.ICMPSequence,
                    self.timeCost * 1000];
        }
            break;
        case 2:{
            desc = [NSString stringWithFormat:@"Request timeout for ping(%@): icmp_seq=%ld",
                    self.host,
                    (long)self.ICMPSequence
                    ];
        }
            break;
        case 3:{
            desc = [NSString stringWithFormat:@"ping(%@): %ld send Error.",
                    self.host,
                    (long)self.ICMPSequence
                    ];
            
        }
            break;
        case 4:{
            desc = [NSString stringWithFormat:@"ping(%@): %ld send Failure.",
                    self.host,
                    (long)self.ICMPSequence
                    ];
            
        }
            break;
        default:
            break;
    }
    return desc;
}

@end


typedef NS_ENUM(NSInteger, DJPingState) {
    DJPingStateIdle,
    DJPingStateStartedSuccess,
    DJPingStateStartedFailure,
    DJPingStateSendDataSuccess,
    DJPingStateSendDataFailure,
    DJPingStateReceiveSuccess,
    DJPingStateReceiveFailure
};


typedef void(^DJPingTimeOutBlock)();


@interface DJPingAction () <DJSimplePingDelegate>

@property(nonatomic, copy) NSString * identifier;
@property(nonatomic, copy) NSString * host;
@property(nonatomic, strong) DJSimplePing * simplePing;
@property(nonatomic, strong) DJPingCompleteBlock completeBlock;
@property(nonatomic, strong) DJPingFeedbackBlock feedbackBlock;
@property(nonatomic, strong) NSData * data;

@property(nonatomic) NSTimeInterval timeOutLimit;               // ping 的超时时间
@property(nonatomic) NSInteger maxCount;                        // ping 的次数
@property(nonatomic) NSTimeInterval durationTime;                   // 最多ping多久

@property(nonatomic) NSInteger currPingCount;
@property(nonatomic) NSDate * sendDate;
@property(nonatomic) uint16_t sequenceNumber;

@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) DJPingTimeOutBlock timeOutBlock;

@property(nonatomic) DJPingState pingState;

@end

@implementation DJPingAction



+(DJPingAction *)startWithHost:(NSString *)host
                  timeOutLimit:(NSTimeInterval)timeOutLimit
                      maxCount:(NSTimeInterval)maxCount
                      feedback:(DJPingFeedbackBlock)feedback
                      complete:(DJPingCompleteBlock)complete{
    
    DJPingAction * pingAction = [DJPingAction new];
    pingAction.host = host;
    pingAction.maxCount = maxCount;
    pingAction.timeOutLimit = timeOutLimit;
    pingAction.simplePing = [[DJSimplePing alloc] initWithHostName:host];
    pingAction.simplePing.delegate = pingAction;
    
    pingAction.queue = dispatch_queue_create("com.sgv.sdk.pingDeteck", DISPATCH_QUEUE_CONCURRENT);
    
    pingAction.feedbackBlock = feedback;
    pingAction.completeBlock = complete;

    
    [pingAction changeState:DJPingStateIdle];
    
    return pingAction;
}

-(void)retry{

}

-(void)changeState:(DJPingState)state{
    switch (state) {
        case DJPingStateIdle:{
            [self.simplePing start];
        }
            break;
        case DJPingStateStartedSuccess:{
            [self.simplePing sendPingWithData:self.data];
        }
            break;
        case DJPingStateStartedFailure:{
        
        }
            break;
        case DJPingStateSendDataSuccess:{
        
        }
            break;
        case DJPingStateSendDataFailure:{
        
        }
            break;
        case DJPingStateReceiveSuccess:{
        }
            break;
        case DJPingStateReceiveFailure:{
        
        }
            break;
    }

}

-(void)startPing{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), self.queue, ^{
        [self.simplePing stop];
        [self.simplePing start];
    });
}

-(void)stopPing{
    [self.simplePing stop];
    dispatch_block_cancel(self.timeOutBlock);
    self.timeOutBlock = nil;
}


-(void)reSendData{
    [self.simplePing sendPingWithData:nil];
    [self.simplePing start];

}

-(void)finishCurrentPingSend:(DJPingItem *)pingItem{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(pingTimeoutActionFired) object:nil];
        self.currPingCount ++;
        if (self.currPingCount < self.maxCount) {

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.05 * NSEC_PER_SEC), self.queue, ^{
                [self rePing];
                [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(pingTimeoutActionFired) object:nil];
                [self performSelector:@selector(pingTimeoutActionFired) withObject:nil afterDelay:self.timeOutLimit];
                [[NSRunLoop currentRunLoop] run];
            });
    
        }else{
            if (self.completeBlock) {
                self.completeBlock();
                self.completeBlock = nil;
            }
        }
}

- (void)pingTimeoutActionFired{
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.sequenceNumber;
    pingItem.timeCost = self.timeOutLimit;
    pingItem.status = 2;
    pingItem.timeToLive = 0;
    
    
    if (self.feedbackBlock) {
        self.feedbackBlock(pingItem);
    }
    
    [self.simplePing stop];
    
    [self finishCurrentPingSend:pingItem];

}


-(void)sendDataComplete:(DJPingFeedbackBlock)feedbackBlock{
    if (feedbackBlock) {
        DJPingItem * item = [DJPingItem new];
        feedbackBlock(item);
    }

}

// Ping的回调
- (void)sgv_simplePing:(DJSimplePing *)pinger didStartWithAddress:(NSData *)address{
    [self changeState:DJPingStateReceiveSuccess];
    
}

- (void)sgv_simplePing:(DJSimplePing *)pinger didFailWithError:(NSError *)error{
    [self changeState:DJPingStateStartedFailure];
    
//    [self.simplePing stop];
//    
//    
//    DJPingItem * pingItem = [[DJPingItem alloc] init];
//    pingItem.host = self.simplePing.hostName;
//    pingItem.ICMPSequence = self.simplePing.identifier;
//    pingItem.timeCost = self.timeOutLimit;
//    pingItem.status = 3;
//    pingItem.timeToLive = 0;
//    
//    
//    if (self.feedbackBlock) {
//        self.feedbackBlock(pingItem);
//    }
//    
//    [self finishCurrentPingSend:pingItem];

}


- (void)sgv_simplePing:(DJSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{
    self.sendDate = [NSDate date];
    self.sequenceNumber = sequenceNumber;
}


- (void)sgv_simplePing:(DJSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error{
 //   [SGVDebugManager logDebug:@"sgv_simplePing didFailToSendPacket sequenceNumber = %i",sequenceNumber];

    
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.simplePing.identifier;
    pingItem.timeCost = self.timeOutLimit;
    pingItem.status = 4;
    pingItem.timeToLive = 0;
    
    if (self.feedbackBlock) {
        self.feedbackBlock(pingItem);
    }
    
    [self finishCurrentPingSend:pingItem];
    
}


- (void)sgv_simplePing:(DJSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{
    
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.sequenceNumber;
    pingItem.timeCost = [[NSDate date] timeIntervalSinceDate:self.sendDate];;
    
    pingItem.status = 1;
    pingItem.timeToLive = 0;
    pingItem.dataByteLenth = packet.length;
    
    if (self.feedbackBlock) {
        self.feedbackBlock(pingItem);
    }
    
    [self finishCurrentPingSend:pingItem];
    
}


- (void)sgv_simplePing:(DJSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet{
    //收到不是自己发的包，忽略
//    [SGVDebugManager logDebug:@"sgv_simplePing didReceiveUnexpectedPacket"];
}



//- (void)simplePing:(DJSimplePing *)pinger didStartWithAddress:(NSData *)address;
//- (void)simplePing:(DJSimplePing *)pinger didFailWithError:(NSError *)error;
//- (void)simplePing:(DJSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;
//- (void)simplePing:(DJSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error;
//- (void)simplePing:(DJSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber;
//- (void)simplePing:(DJSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet;


@end
