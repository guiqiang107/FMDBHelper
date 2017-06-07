//
//  DBHelper.h
//  AYSGPhone
//
//  Created by user on 2016/11/11.
//  Copyright © 2016年 com.guiq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

//系统当前使用db
#define DBName @"AYSGPhone3.0.sqlite3"

//系统历史使用db
#define LastDBName @"AYSGPhone2.1.sqlite3"

@interface DBHelper : NSObject

//单列类
singleton_interface(DBHelper)

@property (nonatomic, strong) FMDatabaseQueue *dbQueue; //FMDatabaseQueue全局唯一队列

/**
 获取数据库路径
 */
+ (NSString *)dbPath;

/**
 创建数据库（Library/Caches/AYSGPhone.sqlite3数据库)
 */
+ (void)createDB;

/**
 删除数据库
 */
+ (BOOL)removeDB;


@end
