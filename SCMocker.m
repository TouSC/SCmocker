//
//  SCMocker.m
//  tpM5
//
//  Created by git on 2018/4/9.
//  Copyright © 2018年 tplink. All rights reserved.
//

#import "SCMocker.h"
#import <objc/runtime.h>

@interface SCMocker ()

@property(nonatomic,strong)NSMutableDictionary *mockMap;
@property(nonatomic,strong)NSMutableDictionary *parameterMap;
@property(nonatomic,strong)NSMutableDictionary *parameterBackupMap; //防止参数被修改
@property(nonatomic,strong)NSMutableDictionary *selectorMap;
@property(nonatomic,assign)BOOL isAllSuccess;

@end

@implementation SCMocker
{
    dispatch_source_t timer;
    NSInvocation *invocation;
}

+ (instancetype)shareInstance{
    if (self.class==[SCMocker class])
    {
        static SCMocker *mocker;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            mocker = [[SCMocker alloc] init];
            Method tmpMethod = class_getInstanceMethod([TMPAppV2Component class], @selector(sendTMPRequest:withPayloadPacker:andResponseUnpackerClass:reprocessBlock:));
            Method cloudMethod = class_getInstanceMethod([TCAppCloudModule class], @selector(sendAppCloudRequest:withPayloadPacker:andResponseUnpackerClass:reprocessBlock:));
            Method newTmpMethod = class_getInstanceMethod([self class], @selector(mySendTMPRequest:withPayloadPacker:andResponseUnpackerClass:reprocessBlock:));
            Method newCloudMethod = class_getInstanceMethod([self class], @selector(mySendAppCloudRequest:withPayloadPacker:andResponseUnpackerClass:reprocessBlock:));
            method_exchangeImplementations(tmpMethod, newTmpMethod);
            method_exchangeImplementations(cloudMethod, newCloudMethod);
            mocker.mockMap = @{}.mutableCopy;
            mocker.parameterMap = @{}.mutableCopy;
            mocker.parameterBackupMap = @{}.mutableCopy;
            mocker.selectorMap = @{}.mutableCopy;
            mocker.isAllSuccess = NO;
        });
        return mocker;
    }
    else
    {
        static SCMocker *mocker;
        static dispatch_once_t subClassOnceToken;
        dispatch_once(&subClassOnceToken, ^{
            mocker = [[self.class alloc] init];
        });
        return mocker;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        ;
    }
    return self;
}

- (void)mock:(NSInteger)tmpCommand result:(NSDictionary*)result isSuccess:(BOOL)isSuccess errorCode:(NSUInteger)errorCode{
    if (isSuccess || [SCMocker shareInstance].isAllSuccess)
    {
        errorCode = 0;
    }
    NSDictionary *fixResult = @{
                                @"error_code":@(errorCode),
                                @"result":result,
                                };
    [[SCMocker shareInstance].mockMap setObject:fixResult forKey:@(tmpCommand)];
}

-(TPAbstractHandle *)mySendAppCloudRequest:(NSInteger)tmpCommand
                  withPayloadPacker:(id)payloadPacker
           andResponseUnpackerClass:(Class)responseUnpackerClassOrNil
                     reprocessBlock:(void (^)(id unpacker, TPHandleResult* result))reprocessBlock{
    TPGCDHandle *handle = [[TPGCDHandle alloc] initWithQueue:dispatch_get_main_queue()];
    TPHandleResult *result = [[TPHandleResult alloc] init];
    NSDictionary *json = [SCMocker shareInstance].mockMap[@(tmpCommand)];
    result.status = [json[@"error_code"] integerValue] ? TPHandleStatusFailure : TPHandleStatusSuccess;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id unpacker = [TMPAppV2Component getUnpacker:responseUnpackerClassOrNil withJsonContent:json];
        reprocessBlock(unpacker, result);
        [handle completeWithResult:result];
    });
    return handle;
}

-(TPAbstractHandle *)mySendTMPRequest:(NSInteger)tmpCommand
                    withPayloadPacker:(id)payloadPacker
             andResponseUnpackerClass:(Class)responseUnpackerClassOrNil
                       reprocessBlock:(void (^)(id unpacker, TPHandleResult* result))reprocessBlock{
    TPGCDHandle *handle = [[TPGCDHandle alloc] initWithQueue:dispatch_get_main_queue()];
    TPHandleResult *result = [[TPHandleResult alloc] init];
    NSDictionary *json = [SCMocker shareInstance].mockMap[@(tmpCommand)];
    result.status = [json[@"error_code"] integerValue] ? TPHandleStatusFailure : TPHandleStatusSuccess;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id unpacker = [TMPAppV2Component getUnpacker:responseUnpackerClassOrNil withJsonContent:json];
        reprocessBlock(unpacker, result);
        [handle completeWithResult:result];
    });
    return handle;
}

-(TPAbstractHandle *)sendTMPRequest:(NSInteger)tmpCommand
                    withPayloadPacker:(id)payloadPacker
             andResponseUnpackerClass:(Class)responseUnpackerClassOrNil
                     reprocessBlock:(void (^)(id unpacker, TPHandleResult* result))reprocessBlock{
    return nil; //消除警告
}

-(TPAbstractHandle *)sendAppCloudRequest:(NSInteger)tmpCommand
                  withPayloadPacker:(id)payloadPacker
           andResponseUnpackerClass:(Class)responseUnpackerClassOrNil
                     reprocessBlock:(void (^)(id unpacker, TPHandleResult* result))reprocessBlock{
    return nil; //消除警告
}

- (void)force:(Class)class_ selector:(SEL)selector success:(BOOL)isSuccess{
    Method originMethod = class_getInstanceMethod(class_, selector);
    NSString *newSelectorName = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(class_), NSStringFromSelector(selector)];
    SEL newSelector = NSSelectorFromString(newSelectorName);
    class_addMethod([self class], newSelector, class_getMethodImplementation(self.class, isSuccess ? @selector(success) : @selector(fail)), method_getTypeEncoding(originMethod));
    Method newMethod = class_getInstanceMethod([self class], newSelector);
    method_exchangeImplementations(originMethod, newMethod);
}

- (BOOL)success{
    return YES;
}

- (BOOL)fail{
    return NO;
}

- (void)force:(Class)class_ selector:(SEL)selector parameters:(NSArray*)parameters{
    NSString *key = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(class_), NSStringFromSelector(selector)];
    [SCMocker shareInstance].selectorMap[key] = parameters;
    Method originMethod = class_getInstanceMethod(class_, selector);
    class_addMethod([SCMocker class], selector, class_getMethodImplementation([SCMocker class], selector), method_getTypeEncoding(originMethod));
    Method newMethod = class_getInstanceMethod([SCMocker class], selector);
    method_exchangeImplementations(originMethod, newMethod);
    class_addMethod(class_, @selector(forwardInvocation:), class_getMethodImplementation([SCMocker class], @selector(forwardInvocation:)), "v@::");
}

- (void)force:(Class)class_ parameter:(NSString*)parameter result:(id)result{
    NSString *key = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(class_), parameter];
    [SCMocker shareInstance].parameterMap[key] = result;
    if ([result respondsToSelector:@selector(mutableCopyWithZone:)])
    {
        [SCMocker shareInstance].parameterBackupMap[key] = [result mutableCopy];
    }
    else if ([result respondsToSelector:@selector(copyWithZone:)])
    {
        [SCMocker shareInstance].parameterBackupMap[key] = [result copy];
    }
    else
    {
        [SCMocker shareInstance].parameterBackupMap[key] = result;
    }
    //添加一个未实现的方法，将其get方法实现交换，唤起消息转发，再交换和SCMocker的消息转发实现
    SEL notExistSelector = @selector(notExistSelector);
    Method originMethod = class_getInstanceMethod(class_, NSSelectorFromString(parameter));
    class_addMethod([SCMocker class], notExistSelector, class_getMethodImplementation([SCMocker class], notExistSelector), method_getTypeEncoding(originMethod));
    Method newMethod = class_getInstanceMethod([SCMocker class], notExistSelector);
    method_exchangeImplementations(originMethod, newMethod);
    class_addMethod(class_, @selector(forwardInvocation:), class_getMethodImplementation([SCMocker class], @selector(forwardInvocation:)), "v@::");
}

- (void)forwardInvocation:(NSInvocation *)anInvocation{
    invocation = anInvocation;
    NSString *key = [NSString stringWithFormat:@"%@_%@", NSStringFromClass([anInvocation.target class]), NSStringFromSelector(anInvocation.selector)];
    id returnValue = [SCMocker shareInstance].parameterMap[key];
    if (returnValue)
    {
        [anInvocation setReturnValue:&returnValue];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            @synchronized(returnValue){
                id backupValue = [SCMocker shareInstance].parameterBackupMap[key];
                if ([backupValue respondsToSelector:@selector(mutableCopyWithZone:)])
                {
                    [SCMocker shareInstance].parameterMap[key] = [backupValue mutableCopy];
                }
                else if ([returnValue respondsToSelector:@selector(copyWithZone:)])
                {
                    [SCMocker shareInstance].parameterMap[key] = [backupValue copy];
                }
                else
                {
                    [SCMocker shareInstance].parameterMap[key] = backupValue;
                }
            }
        });
    }
    NSArray *paras = [SCMocker shareInstance].selectorMap[key];
    if (paras.count)
    {
        for (int i=0; i<paras.count; i++)
        {
            //0 self 1 selector
            id para = paras[i];
            [anInvocation setArgument:&para atIndex:i+2];
        }
        Method originMethod = class_getInstanceMethod([anInvocation.target class], anInvocation.selector);
        Method newMethod = class_getInstanceMethod([SCMocker class], anInvocation.selector);
        method_exchangeImplementations(originMethod, newMethod);
        [anInvocation invoke];
        method_exchangeImplementations(originMethod, newMethod);
    }
}

- (void)testAllSuccess{
    Method originMethod = class_getInstanceMethod([TPHandleResult class], @selector(success));
    Method newMethod = class_getInstanceMethod([self class], @selector(mySuccess));
    method_exchangeImplementations(originMethod, newMethod);
    
    Method originBlePowerOnMethod = class_getInstanceMethod([TPBluetoothKit class], @selector(isPowerOn));
    Method originBlePairedMethod = class_getInstanceMethod([TPBluetoothKit class], @selector(isPaired));
    Method newBlePowerOnMethod = class_getInstanceMethod([self class], @selector(myIsPowerOn));
    Method newBlePairedMethod = class_getInstanceMethod([self class], @selector(myIsPaired));
    method_exchangeImplementations(originBlePowerOnMethod, newBlePowerOnMethod);
    method_exchangeImplementations(originBlePairedMethod, newBlePairedMethod);
    [[SCMocker shareInstance] setIsAllSuccess:YES];
}

- (BOOL)mySuccess{
    return YES;
}

- (BOOL)myIsPowerOn{
    return YES;
}

- (BOOL)myIsPaired{
    return YES;
}

- (void)startTimer:(void(^)(BOOL isLag, NSString *info))block{
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        block(NO, nil);
    });
    dispatch_resume(timer);
}

@end
