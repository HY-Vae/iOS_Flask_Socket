//
//  ViewController.m
//  iOS_Flask_Socket
//
//  Created by fly on 2020/3/15.
//  Copyright © 2020 admin. All rights reserved.
//

#import "ViewController.h"
#import <GCDAsyncSocket.h>
@interface ViewController ()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSMutableData *cacheData;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)didPressedConnect:(id)sender {
    NSError *error = nil;
    UIButton *btn = (UIButton *)sender;
    if ([btn.titleLabel.text isEqualToString:@"连接"]) {
        //开始连接socket
        [self.socket connectToHost:self.IPTextField.text onPort:[self.PortTextField.text intValue] error:&error];
        [btn setTitle:@"断开" forState:0];
    }
    else if ([btn.titleLabel.text isEqualToString:@"断开"]){
        //断开socket
        [self.socket disconnect];
        [btn setTitle:@"连接" forState:0];
    }
    if (error) {
        NSLog(@"%@",error);
    }
}
- (IBAction)didPressedSend:(id)sender {
    [self.socket writeData:[self.inputTextField.text dataUsingEncoding:NSUTF8StringEncoding]
                   withTimeout:-1
                           tag:0];
    self.lblResult.text = [NSString stringWithFormat:@"发送给服务器的消息: %@", self.inputTextField.text];
}

/*
因为存在粘包和分包的情况，所以接收方需要对接收的数据进行一定的处理，主要解决的问题有两个：
在粘包产生时，要可以在同一个包内获取出多个包的内容。
在分包产生时，要保留上一个包的部分内容，与下一个包的部分内容组合。
处理方式：
在数据包头部加上内容长度以及数据类型
 */
#pragma mark - 发送数据格式化
- (void)sendData:(NSData *)data dataType:(unsigned int)dataType{
    NSMutableData *mData = [NSMutableData data];
    // 1.计算数据总长度 data
    unsigned int dataLength = 4+4+(int)data.length;
    // 将长度转成data
    NSData *lengthData = [NSData dataWithBytes:&dataLength length:4];
    // mData 拼接长度data
    [mData appendData:lengthData];
    
    // 数据类型 data
    // 2.拼接指令类型(4~7:指令)
    NSData *typeData = [NSData dataWithBytes:&dataType length:4];
    // mData 拼接数据类型data
    [mData appendData:typeData];
    
    // 3.最后拼接真正的数据data
    [mData appendData:data];
    NSLog(@"发送数据的总字节大小:%ld",mData.length);
    
    // 发数据
    [self.socket writeData:mData withTimeout:-1 tag:10086];
}

#pragma mark - 返回格式数据格式化解码
- (void)recvData:(NSData *)data{
    //直接就给他缓存起来
    [self.cacheData appendData:data];
    // 获取总的数据包大小
    // 整段数据长度(不包含长度跟类型)
    NSData *totalSizeData = [data subdataWithRange:NSMakeRange(0, 4)];
    unsigned int totalSize = 0;
    [totalSizeData getBytes:&totalSize length:4];
    //包含长度跟类型的数据长度
    unsigned int completeSize = totalSize  + 8;
    //必须要大于8 才会进这个循环
    while (self.cacheData.length>8) {
        if (self.cacheData.length < completeSize) {
            //如果缓存的长度 还不如 我们传过来的数据长度，就让socket继续接收数据
            [self.socket readDataWithTimeout:-1 tag:10086];
            break;
        }
        //取出数据
        NSData *resultData = [self.cacheData subdataWithRange:NSMakeRange(8, completeSize)];
        //处理数据
        NSString *receiverStr = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
        [self showResult:[NSString stringWithFormat:@"接收到的服务器消息: %@", receiverStr]];
        //清空刚刚缓存的data
        [self.cacheData replaceBytesInRange:NSMakeRange(0, completeSize) withBytes:nil length:0];
        //如果缓存的数据长度还是大于8，再执行一次方法
        if (self.cacheData.length > 8) {
            [self recvData:nil];
        }
    }
}

//socket操作在子线程，回到主线程更新UI
- (void)showResult:(NSString *)result{
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.lblResult.text = result;
    });
}

#pragma mark - delegate
//连接成功
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    [self.socket readDataWithTimeout:-1 tag:0];
    [self showResult:[NSString stringWithFormat:@"连接成功: %@", host]];
}

//断开连接
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    if (err) {
        [self showResult:[NSString stringWithFormat:@"连接失败: %@", err.localizedDescription]];
    }
    else{
        [self showResult:[NSString stringWithFormat:@"正常断开: %@", err.localizedDescription]];
    }
}

//给服务器发送成功后
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    // 发送完数据手动读取，-1不设置超时
    [self.socket readDataWithTimeout:-1 tag:0];
    [self showResult:[NSString stringWithFormat:@"消息发送成功, 用户ID号为: %ld", tag]];
}

//接受服务器发送过来的消息
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    if (!data) {
        [self showResult:@"没有接收到服务器的消息"];
        return;
    }
    NSString *receiverStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self showResult:[NSString stringWithFormat:@"接收到的服务器消息: %@", receiverStr]];
    //  准备读取下次的数据
    [self.socket readDataWithTimeout:-1 tag:0];
}

#pragma mark - getter and setter
- (GCDAsyncSocket *)socket {
    if (!_socket) {
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                              delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    }
    return _socket;
}

@end
