
///
//  DBHelper.m
//  AYSGPhone
//
//  Created by user on 2016/11/11.
//  Copyright © 2016年 com.guiq. All rights reserved.
//

#import "DBHelper.h"

@implementation DBHelper

singleton_implementation(DBHelper)


+ (void)initialize
{
    //创建新的数据库
    [self createDB];
}

- (FMDatabaseQueue *)dbQueue{
    if (!_dbQueue) {
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[[self class] dbPath]];
    }
    return _dbQueue;
}

+ (NSString *)dbPath
{
    return [self dbPathWithName:DBName];
}

+ (void)createDB
{
    //新版本数据库路径
    NSString *dbPath = [self dbPath];
    DLog(@"dbPath:%@",dbPath);

    //创建数据库
    [self sharedDBHelper].dbQueue =[FMDatabaseQueue databaseQueueWithPath:dbPath];
    
    //删除旧版本数据库
    [self removeDBDBWithName:LastDBName];
}

+ (BOOL)removeDB
{
    return [self removeDBDBWithName:DBName];
}

#pragma mark - private
+ (NSString *)dbPathWithName:(NSString *)name
{
    //获取cache路径
    NSString *cache = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dbPath = [cache stringByAppendingPathComponent:name];
    
    return dbPath;
}


+ (BOOL)removeDBDBWithName:(NSString *)name
{
    NSString *dbPath = [self dbPathWithName:name];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL success = [fm fileExistsAtPath:dbPath];
    
    BOOL removeState = NO;
    if(success){
        removeState = [fm removeItemAtPath:dbPath error:nil];
    }
//    DLog(@"%@",[NSString stringWithFormat:@"数据库(%@)删除%@",name,removeState ? @"成功":@"失败"]);
    return removeState;
}

@end
