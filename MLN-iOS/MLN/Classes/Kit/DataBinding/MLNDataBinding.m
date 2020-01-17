//
//  MLNDataBinding.m
//  LuaNative
//
//  Created by tamer on 2020/1/15.
//  Copyright © 2020 liu.xu_1586. All rights reserved.
//

#import "MLNDataBinding.h"
#import "MLNKVObserverHelper.h"
#import <pthread.h>

@interface MLNDataBinding () {
    pthread_mutex_t _lock;
}

@property (nonatomic, strong) NSMutableDictionary *dataMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, MLNKVObserverHelper *> *observerHelperMap;

@end
@implementation MLNDataBinding

- (instancetype)init
{
    if (self = [super init]) {
        _dataMap = [NSMutableDictionary dictionary];
        _observerHelperMap = [NSMutableDictionary dictionary];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_lock);
}

- (void)bindData:(NSObject *)data key:(NSString *)key
{
    pthread_mutex_lock(&_lock);
    [self.dataMap setObject:data forKey:key];
    pthread_mutex_unlock(&_lock);
}

- (void)updateDataForKeyPath:(NSString *)keyPath value:(id)value
{
    id data = nil;
    NSString *key = nil;
    BOOL success = [self parseByKeyPath:keyPath retData:&data retKey:&key];
    if (success) {
        [data setValue:value forKeyPath:key];
    }
}

- (id __nullable)dataForKeyPath:(NSString *)keyPath
{
    id data = nil;
    NSString *key = nil;
    BOOL success = [self parseByKeyPath:keyPath retData:&data retKey:&key];
    if (success) {
        data = [data valueForKeyPath:key];
    }
    return data;
}

- (void)addDataObserver:(NSObject<MLNKVObserverProtocol> *)observer forKeyPath:(NSString *)keyPath
{
    NSParameterAssert(keyPath);
    NSParameterAssert(observer);
    if (!keyPath || !observer) {
        return;
    }
    // cache
    pthread_mutex_lock(&_lock);
    MLNKVObserverHelper *helper = [self.observerHelperMap objectForKey:keyPath];
    pthread_mutex_unlock(&_lock);
    if (helper) {
        [helper addObserver:observer];
        return;
    }
    // new
    id data = nil;
    NSString *key = nil;
    BOOL success = [self parseByKeyPath:keyPath retData:&data retKey:&key];
    if (success) {
        helper = [[MLNKVObserverHelper alloc] initWithTargetObject:data keyPath:key];
        [helper addObserver:observer];
        pthread_mutex_lock(&_lock);
        [self.dataMap setValue:helper forKey:keyPath];
        pthread_mutex_unlock(&_lock);
    }
}

- (BOOL)parseByKeyPath:(NSString *)keyPath retData:(id *)retData retKey:(NSString **)retKey
{
    if (retData == NULL || retKey == NULL) {
        return NO;
    }
    NSArray<NSString *> *keyPathArray = [keyPath componentsSeparatedByString:@"."];
    if (keyPathArray.count > 1) {
        NSString *firstKey = keyPathArray.firstObject;
        pthread_mutex_lock(&_lock);
        id data = [self.dataMap objectForKey:firstKey];
        pthread_mutex_unlock(&_lock);
        NSString *akey = nil;
        if (data) {
            for (int i = 1; i < keyPathArray.count; i++) {
                akey = [keyPathArray objectAtIndex:1];
                if (!akey) {
                    return NO;
                }
                NSString *setterKey = [NSString stringWithFormat:@"set%@:",[akey capitalizedString]];
                if (![data respondsToSelector:NSSelectorFromString(akey)] ||
                    ![data respondsToSelector:NSSelectorFromString(setterKey)]) {
                    return NO;
                }
                if (i == keyPathArray.count - 2) {
                    data = [data valueForKey:akey];
                }
            }
        }
        *retData = data;
        *retKey = akey;
        return YES;
    }
    return NO;
}

@end
