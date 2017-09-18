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
    DJPingStateStartedSuccess,      //1
    DJPingStateStartedFailure,      //2
    DJPingStateSendDataSuccess,     //3
    DJPingStateSendDataFailure,     //4
    DJPingStateReceiveSuccess,      //5
    DJPingStateReceiveFailure       //6
};


typedef void(^DJPingTimeOutBlock)();

typedef void(^DJPingResultBlockWrap)(DJPingCompleteBlock block);


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
@property(nonatomic) BOOL stopWhenReached;                      //是否通了就不继续了

@property(nonatomic) NSInteger currPingCount;
@property(nonatomic) NSDate * sendDate;
@property(nonatomic) uint16_t sequenceNumber;

@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) DJPingTimeOutBlock timeOutBlock;

@property(nonatomic) DJPingState pingState;

@property(nonatomic, strong) NSMutableDictionary * timeDic;

@property(nonatomic, strong) DJPingAction * myself; //在完成之前,hold住自己

@end

@implementation DJPingAction



+(DJPingAction *)startWithHost:(NSString *)host
                  timeOutLimit:(NSTimeInterval)timeOutLimit
               stopWhenReached:(BOOL)stopWhenReached
                      maxCount:(NSTimeInterval)maxCount
                      feedback:(DJPingFeedbackBlock)feedback
                      complete:(DJPingCompleteBlock)complete{
    
    DJPingAction * pingAction = [DJPingAction new];
    pingAction.host = host;
    pingAction.stopWhenReached = stopWhenReached;
    pingAction.maxCount = maxCount;
    pingAction.timeOutLimit = timeOutLimit;
    pingAction.timeDic = [NSMutableDictionary dictionary];
    pingAction.simplePing = [[DJSimplePing alloc] initWithHostName:host];
    pingAction.simplePing.delegate = pingAction;
    pingAction.feedbackBlock = feedback;
    if (complete) {
        pingAction.completeBlock = complete;
        pingAction.myself = pingAction;
        
    }
    
    pingAction.queue = dispatch_queue_create("com.sgv.sdk.pingDeteck", DISPATCH_QUEUE_CONCURRENT);

    dispatch_async(pingAction.queue, ^{
        [pingAction changeState:DJPingStateIdle withItem:nil];
        [[NSRunLoop currentRunLoop] run];
    });
    
    return pingAction;
}


-(void)changeState:(DJPingState)state withItem:(DJPingItem *)item{
    NSLog(@"ping changeState state = %@",@(state));
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
            [self finishCurrPingAndGoToState:DJPingStateIdle withItem:item];
        }
            break;
        case DJPingStateSendDataSuccess:{
            // 启动计时
            [self performSelector:@selector(pingTimeoutActionFired)
                       withObject:nil
                       afterDelay:self.timeOutLimit];
            NSLog(@"timer start");

        }
            break;
        case DJPingStateSendDataFailure:{
            [self finishCurrPingAndGoToState:DJPingStateStartedSuccess withItem:item];
        }
            break;
        case DJPingStateReceiveSuccess:{
            [self finishCurrPingAndGoToState:DJPingStateStartedSuccess withItem:item];
        }
            break;
        case DJPingStateReceiveFailure:{
            [self finishCurrPingAndGoToState:DJPingStateStartedSuccess withItem:item];
        }
            break;
    }

}

-(void)finishCurrPingAndGoToState:(DJPingState)state withItem:(DJPingItem *)item{
    
    [[self class] cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(pingTimeoutActionFired)
                                                   object:nil];
    NSLog(@"timer cancel");
    
    if (self.feedbackBlock) {
        self.feedbackBlock(item);
    }
    self.currPingCount ++;
    
    if (item.status == 1 && self.stopWhenReached) {
        if (self.completeBlock) {
            self.completeBlock();
            self.myself = nil;
            self.completeBlock = nil;
            self.feedbackBlock = nil;
        }
    }else {
        if (self.currPingCount < self.maxCount) {
            // 没到次数，重试
            [self changeState:state withItem:item];
        }else{
            // 达到重试次数
            if (self.completeBlock) {
                self.completeBlock();
                self.myself = nil;
                self.completeBlock = nil;
                self.feedbackBlock = nil;
            }
        }
    }

    
}


- (void)pingTimeoutActionFired{
    NSLog(@"timer timeout");
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.sequenceNumber;
    pingItem.timeCost = self.timeOutLimit;
    pingItem.status = 2;
    pingItem.timeToLive = 0;
    
    [self changeState:DJPingStateReceiveFailure withItem:pingItem];
}

//---------------------------------------------------------------------------

// Ping的回调
- (void)dj_simplePing:(DJSimplePing *)pinger didStartWithAddress:(NSData *)address{
    NSLog(@"sgv_simplePing didStartWithAddress");
    [self changeState:DJPingStateStartedSuccess withItem:nil];
    
}

- (void)dj_simplePing:(DJSimplePing *)pinger didFailWithError:(NSError *)error{
    NSLog(@"sgv_simplePing didFailWithError error = %@", error);
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.simplePing.identifier;
    pingItem.timeCost = self.timeOutLimit;
    pingItem.status = 3;
    pingItem.timeToLive = 0;
    
    [self changeState:DJPingStateStartedFailure withItem:pingItem];

}


- (void)dj_simplePing:(DJSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{

    self.sendDate = [NSDate date];
    [self.timeDic setObject:[NSDate date] forKey:@(sequenceNumber)];
    NSLog(@"sgv_simplePing didSendPacket sequenceNumber = %d data=%f", sequenceNumber,[self.sendDate timeIntervalSince1970]);

    self.sequenceNumber = sequenceNumber;
    
    [self changeState:DJPingStateSendDataSuccess withItem:nil];
}


- (void)dj_simplePing:(DJSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error{

    
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.simplePing.identifier;
    pingItem.timeCost = self.timeOutLimit;
    pingItem.status = 4;
    pingItem.timeToLive = 0;
    
    [self changeState:DJPingStateSendDataFailure withItem:pingItem];
    
    
}


- (void)dj_simplePing:(DJSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber{
    
    DJPingItem * pingItem = [[DJPingItem alloc] init];
    pingItem.host = self.simplePing.hostName;
    pingItem.ICMPSequence = self.sequenceNumber;
    NSDate * nowDate = [NSDate date];
    NSDate * sendDate = [self.timeDic objectForKey:@(sequenceNumber)];
    pingItem.timeCost = [nowDate timeIntervalSinceDate:sendDate];;
    
    pingItem.status = 1;
    pingItem.timeToLive = 0;
    pingItem.dataByteLenth = packet.length;
    

    NSLog(@"sgv_simplePing didReceivePingResponsePacket sequenceNumber = %d pingItem = %@ data=%f sendDate=%f", sequenceNumber, pingItem,[nowDate timeIntervalSince1970],[sendDate timeIntervalSince1970]);

    // 成功收到超时发出的包，则忽略
    if (pinger.nextSequenceNumber == sequenceNumber + 1) {
        [self changeState:DJPingStateReceiveSuccess withItem:pingItem];
    }
    
}


- (void)dj_simplePing:(DJSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet{
    //收到不是自己发的包，忽略
//    [SGVDebugManager logDebug:@"sgv_simplePing didReceiveUnexpectedPacket"];
}


@end
