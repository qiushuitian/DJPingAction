# DJPingAction

检测网络的连通性,一般会用ping操作.即向主机发送一个ICMP的包.这些动作都需要自己实现.好在苹果的[SimplePing代码](https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html)中帮我们实现了一个简单的ping操作.即封装了底层往主机发ICMP包的过程.但是这个ping操作还是过于简陋,它只管了如何发ICMP包.对一些典型的业务场景,比如检测网络连通性,使用起来还是相对复杂.

DJPingAction就是在苹果的[SimplePing](https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html)基础上封装了典型的业务场景. 

## 安装

    pod 'DJPingAction'

## 使用

```
#import "DJPingAction.h"

[DJPingAction startWithHost:@"qq.com"
                   timeOutLimit:1.0f
                stopWhenReached:NO
                       maxCount:3
                       feedback:^(DJPingItem *item) {
        NSLog(@"ping Action item = %@",item);
    } complete:^{
        NSLog(@"ping Action finished!");
    }];
```
