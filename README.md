# DJPingAction

检测网络的连通性,一般会用ping操作.即向主机发送一个ICMP的包.苹果的[SimplePing代码](https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html)中帮我们实现了一个简单的ping操作.即封装了底层往主机发ICMP包的过程.但是这个ping操作还是过于简陋,它只管了如何发ICMP包.对一些典型的业务场景,比如检测网络连通性,使用起来还是相对复杂.

DJPingAction就是在苹果的[SimplePing](https://developer.apple.com/library/content/samplecode/SimplePing/Introduction/Intro.html)基础上进行了封装.

* 封装了SimplePing的各种代理.一般情况下,我们对Ping的发包过程并不关心,只关心包的到达结果.因此对外只提供包到达结果即可.

* 封装了超时的机制.SimplePing只是管了发ICMP包,并没有对超时没有收到包的情况做处理.

* 封装了对象管理. 调用`DJPingAction startWithHost:timeOutLimit:stopWhenReached:maxCount:feedback:complete`之后,内部会维护一个DJPingAction对象,在complete的block回来之后,这个对象一直存在.不需要再调用的地方维护DJPingAction 对象.

* 让ping的动作在单独的线程中执行.

## 安装

    pod 'DJPingAction'

## 使用

```
#import "DJPingAction.h"

// host: 主机名
// timeOutLimit: ICMP包发出去之后,多久没收到即认为超时.单位 秒.
// stopWhenReached: 是否已经收到一个成功包之后,后面的包就不用再发了.一般用于典型的网络连通性检测中.
// maxCount: 最大包的个数
// feedback: 每个包的发送结果回调
// complete: ping动作完成之后的回调. 执行这个回调之后,释放所有内部对象.

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


