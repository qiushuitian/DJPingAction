//
//  DJPingAction.h
//
//  Created by dengjian on 2017/3/10.
//  Copyright © 2017年 dengjian. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DJSimplePing;


@interface DJPingItem : NSObject

@property(nonatomic, copy) NSString *   host;                       // 主机名
@property(nonatomic) NSTimeInterval     timeCost;                   // 延时
@property(nonatomic) NSInteger          timeToLive;                 // TTL
@property(nonatomic) NSInteger          ICMPSequence;               // 序列号
@property(nonatomic) NSInteger          status;                     // 状态 1 成功  2 超时  3 错误 4 发包失败
@property(nonatomic) NSInteger          dataByteLenth;              // 包大小
@end

typedef void(^DJPingResultBlock)(NSArray * pingItems);
typedef void(^DJPingFeedbackBlock)(DJPingItem * item);
typedef void(^DJPingCompleteBlock)();

@interface DJPingAction : NSObject


+(DJPingAction *)startWithHost:(NSString *)host
                  timeOutLimit:(NSTimeInterval)timeOutLimit
                      maxCount:(NSTimeInterval)maxCount
                      feedback:(DJPingFeedbackBlock)feedback
                      complete:(DJPingCompleteBlock)complete;



@end
