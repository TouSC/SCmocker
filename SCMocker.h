//
//  SCMocker.h
//
//  Created by git on 2018/4/9.
//  Copyright © 2018年 tplink. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCMocker : NSObject

@property(nonatomic,strong)NSString *className;

+ (instancetype)shareInstance;

- (void)testAllSuccess;
- (void)mock:(NSInteger)tmpCommand result:(NSDictionary*)result isSuccess:(BOOL)isSuccess errorCode:(NSUInteger)errorCode;
- (void)force:(Class)class_ selector:(SEL)selector success:(BOOL)isSuccess;
- (void)force:(Class)class_ selector:(SEL)selector parameters:(NSArray*)parameters;
- (void)force:(Class)class_ parameter:(NSString*)parameter result:(id)result;
- (void)startTimer:(void(^)(BOOL isLag, NSString *info))block;    //这里调试或检查卡顿

@end
