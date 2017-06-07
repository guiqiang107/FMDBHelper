
//
//  DBModel.m
//  AYSGPhone
//
//  Created by user on 2016/11/11.
//  Copyright © 2016年 com.guiq. All rights reserved.
//

#import "DBModel.h"
#import <objc/runtime.h>

/** SQLite数据类型 */
NSString *const SQLTEXT = @"TEXT";
NSString *const SQLINTEGER = @"INTEGER";
NSString *const SQLREAL = @"REAL";
NSString *const SQLBOOL = @"BOOL";

#define NIl_STR(str)  str ? str : @""

@interface DBModel ()

/** 列名 */
@property (retain, readonly, nonatomic) NSMutableArray *columeNames;
/** 列类型 */
@property (retain, readonly, nonatomic) NSMutableArray *columeTypes;

@end

@implementation DBModel

#pragma mark - 初始化建表
+ (void)initialize
{
    if (self != [DBModel self]) {
        [self createTable];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        NSDictionary *dic = [self.class getAllProperties];
        _columeNames = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"name"]];
        _columeTypes = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"type"]];
        _timestamp = [[NSDate date] timeIntervalSince1970];
    }
    
    return self;
}

#pragma mark - 表
+ (BOOL)isExistTable
{
    __block BOOL res = YES;
    DBHelper *helper = [DBHelper sharedDBHelper];
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        res =[db tableExists:[self tableName]];
    }];
    return res;
}

/**
 * 创建表
 * 如果已经创建，返回YES
 */
+ (BOOL)createTable
{
    __block BOOL res = YES;
    DBHelper *helper = [DBHelper sharedDBHelper];
    [helper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *tableName = [self tableName];
        NSString *columeAndType = [self.class getColumeAndTypeString];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
        if (![db executeUpdate:sql]) {
            res = NO;
            *rollback = YES;
            return;
        };
        
        //本地数据库表中所有列
        NSMutableArray *columns = [NSMutableArray array];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        [resultSet close];
        
        //模型类所有属性字段
        NSDictionary *dict = [self.class getAllProperties];
        NSArray *properties = [dict objectForKey:@"name"];

        //过滤数组(添加数据库表中不包含的模型属性列)
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
        NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
        for (NSString *column in resultArray) {
            NSUInteger index = [properties indexOfObject:column];
            NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",[self tableName],fieldSql];
            if (![db executeUpdate:sql]) {
                res = NO;
                *rollback = YES;
                return ;
            }
        }

    }];
    
    return res;
}

/** 清空表 */
+ (BOOL)clearTable
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    __block BOOL res = YES;
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        res = [db executeUpdate:sql];
    }];
    return res;
}

#pragma mark - 更新或保存
/** 批量保存用户对象 */
+ (BOOL)saveOrUpdateObjects:(NSArray *)array
{
    __block BOOL res = YES;
    DBHelper *helper = [DBHelper sharedDBHelper];
    //事务
    [helper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (DBModel *model in array) {
            
            if (![model isKindOfClass:[DBModel class]]) {
                return;
            }
            
            BOOL flag = NO;
            NSArray *sqlArray = nil;
            
            NSString *tableName = [self tableName];
            NSString *primaryKey = [self primaryKey];
            
            //存在主键,直接根据主键查询,若查询出记录,则更新;若无记录,则插入
            if (primaryKey) {
                
                id primaryValue = [model valueForKey:primaryKey];
                
                //查询记录
                BOOL isExist = NO;
                NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@'",tableName,primaryKey,primaryValue];
                FMResultSet *aResult = [db executeQuery:sql];
                if([aResult next]){
                    isExist = YES;
                }
                [aResult close];
                
                //存在记录，更新
                if (isExist) {
                    sqlArray = [self getUpdateSql:model];
                    
                }
                //不存在记录,插入
                else{
                    sqlArray = [self getInsertSql:model];
                }
                
            }
            //不存在主键,全部插入
            else{
                sqlArray = [self getInsertSql:model];
            }
            
            flag = [db executeUpdate:sqlArray[0] withArgumentsInArray:sqlArray[1]];
            
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

+ (BOOL)updateObj:(DBModel *)model condition:(NSString *)condition
{
    __block BOOL res = YES;
    DBHelper *helper = [DBHelper sharedDBHelper];
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSAssert(model, @"模型不能为nil");
        NSString *tableName = [self tableName];
        
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < model.columeNames.count; i++) {
            NSString *proname = [model.columeNames objectAtIndex:i];
            
            [keyString appendFormat:@" %@=?,", proname];
            id value = NIl_STR([model valueForKey:proname]);
            [updateValues addObject:value];
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@;", tableName, keyString, condition];
        
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
    }];
    return res;
}

#pragma mark - 删除
/** 通过条件删除数据 */
+ (BOOL)deleteObjByCondition:(NSString *)condition;
{
    if (!condition) {
        NSAssert(condition, @"condition不能为nil");
        return NO;
    }
    
    DBHelper *helper = [DBHelper sharedDBHelper];
    
    __block BOOL res = YES;
    
    NSString *tableName = [self tableName];
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@",tableName,condition];
        res = [db executeUpdate:sql];
    }];
    return res;
}

/** 批量删除用户对象 */
+ (BOOL)deleteObjects:(NSArray *)array
{
    __block BOOL res = YES;
    DBHelper *helper = [DBHelper sharedDBHelper];
    // 如果要支持事务
    [helper.dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (DBModel *model in array) {
            if (![model isKindOfClass:[DBModel class]]) {
                return;
            }
            
            NSString *tableName = [self tableName];
            NSString *primaryKey = [self primaryKey];
            id primaryValue = [model valueForKey:primaryKey];
            
            if (!primaryKey) {
                NSAssert(tableName, @"批量删除必须设置主键");
                return;
            }
            if (!primaryValue) {
                NSAssert(tableName, @"主键不能为nil");
                return;
            }
            
            NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = '%@'",tableName,primaryKey,primaryValue];
            BOOL flag = [db executeUpdate:sql];
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

#pragma mark - 查询
+ (BOOL)isExits:(DBModel *)model
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    __block BOOL exits = NO;
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = [self tableName];
        NSString *pk = [self primaryKey];
        id primaryValue = [model valueForKey:pk];
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ = '%@'",tableName,pk,primaryValue];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            exits = YES;
            break;
        }
        [resultSet close];
    }];
    return exits;
}

+ (id)findFirstObjByCondition:(NSString *)condition
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    __block DBModel *model = nil;
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = [self tableName];
        
        NSString *sql = nil;
        if (!condition) {
            sql = [NSString stringWithFormat:@"SELECT * FROM %@ limit 1",tableName];
        }else{
            sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@ limit 1",tableName,condition];
        }
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            model = [[self.class alloc] init];
            for (int i=0; i< model.columeNames.count; i++) {
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                if ([columeType isEqualToString:SQLTEXT]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            FMDBRelease(model);
            break;
        }
        
        [resultSet close];
    }];
    
    return model;
}

/** 根据条件查找数据（condition为sql where开始）
 *  condition = nil表示查询全部数据
 */
+ (NSArray *)findObjsByCondition:(NSString *)condition
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    NSMutableArray *users = [NSMutableArray array];
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *tableName = [self tableName];
        
        NSString *sql = nil;
        if (!condition) {
            sql = [NSString stringWithFormat:@"SELECT * FROM %@",tableName];
        }else{
            sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@",tableName,condition];
        }
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            DBModel *model = [[self.class alloc] init];
            for (int i=0; i< model.columeNames.count; i++) {
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                if ([columeType isEqualToString:SQLTEXT]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            [users addObject:model];
            FMDBRelease(model);
        }
        
        [resultSet close];
    }];
    
    return users;
}

+ (NSInteger)findAllCounts
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    
    __block NSInteger count = 0;
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        NSString *sql = [NSString stringWithFormat:@"select count(*) from %@",tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        if ([resultSet next]) {
            count = [resultSet intForColumnIndex:0];
        }
        [resultSet close];
    }];
    return count;
}

#pragma mark - Util Methods
/**
 *  获取类的所有属性
 */
+ (NSDictionary *)getPropertys
{
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    
    NSArray *theIgnoredPropertys = [[self class] ignoredProperty];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        
        //获取属性名
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if ([theIgnoredPropertys containsObject:propertyName]) {
            continue;
        }
        [proNames addObject:propertyName];
        //获取属性类型等参数
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         c char         C unsigned char
         i int          I unsigned int
         l long         L unsigned long
         s short        S unsigned short
         d double       D unsigned double
         f float        F unsigned float
         q long long    Q unsigned long long
         B BOOL
         @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
         
         
         64位下long 和long long 都是Tq
         SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
         */
        if ([propertyType hasPrefix:@"T@"]) {
            [proTypes addObject:SQLTEXT];
        }else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||[propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"] || [propertyType hasPrefix:@"Tq"] || [propertyType hasPrefix:@"TQ"] || [propertyType hasPrefix:@"Tl"] || [propertyType hasPrefix:@"TL"] || [propertyType hasPrefix:@"Td"] || [propertyType hasPrefix:@"TD"]) {
            [proTypes addObject:SQLINTEGER];
        }else if([propertyType hasPrefix:@"TB"]){
            [proTypes addObject:SQLBOOL];
        }
        else {
            [proTypes addObject:SQLREAL];
        }
        
    }
    free(properties);

    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 获取所有属性，包含主键pk */
+ (NSDictionary *)getAllProperties
{
    //先获取本类属性
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:[self.class getPropertys]];
    
    NSMutableArray *proNames = [NSMutableArray arrayWithArray:dict[@"name"]];
    NSMutableArray *proTypes = [NSMutableArray arrayWithArray:dict[@"type"]];
    
    //再获取父类属性(统一插入时间戳)
    id supClass = [self superclass];
    if (supClass != [NSObject class]) {
        
        NSDictionary *supDict = [[self superclass] getAllProperties];
        [proNames addObjectsFromArray:supDict[@"name"]];
        [proTypes addObjectsFromArray:supDict[@"type"]];
    }

    NSDictionary *map = [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
    return map;
}

+ (NSString *)getColumeAndTypeString
{
    NSMutableString* pars = [NSMutableString string];
    NSDictionary *dict = [self.class getAllProperties];
    
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    NSMutableArray *proTypes = [dict objectForKey:@"type"];
    
    for (int i=0; i< proNames.count; i++) {
        NSString *pName = proNames[i];
        NSString *pType = proTypes[i];
        [pars appendFormat:@"%@ %@",pName,pType];
        
        NSString *pk = [self primaryKey];
        if ( pk && [pName isEqualToString:pk]) {
             [pars appendString:@" PRIMARY KEY"];
        }
        
        if(i+1 != proNames.count)
        {
            [pars appendString:@","];
        }
    }
    return pars;
}

+ (NSArray *)getColumns
{
    DBHelper *helper = [DBHelper sharedDBHelper];
    NSMutableArray *columns = [NSMutableArray array];
    [helper.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        [resultSet close];
    }];
    return [columns copy];
}

/**
 拼接更新sql和参数
 
 @param model 要插入数据库的模型
 @return array = [@"sql",@[Arguments]]，array[0]为sql,array[1]为参数
 */
+ (NSArray *)getUpdateSql:(DBModel *)model
{
    NSAssert(model, @"模型不能为nil");
    NSString *tableName = [self tableName];
    NSString *primaryKey = [self primaryKey];
    id primaryValue = [model valueForKey:primaryKey];
    
    NSMutableString *keyString = [NSMutableString string];
    NSMutableArray *updateValues = [NSMutableArray  array];
    for (int i = 0; i < model.columeNames.count; i++) {
        NSString *proname = [model.columeNames objectAtIndex:i];
        if ([proname isEqualToString:primaryKey]) {
            continue;
        }
        [keyString appendFormat:@" %@=?,", proname];
        id value = NIl_STR([model valueForKey:proname]);
        [updateValues addObject:value];
    }
    
    //删除最后那个逗号
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?;", tableName, keyString, primaryKey];
    [updateValues addObject:primaryValue];
    return @[sql,updateValues];
    
}

/**
 拼接插入sql和参数
 
 @param model 要插入数据库的模型
 @return array = [@"sql",@[Arguments]]，array[0]为sql,array[1]为参数
 */
+ (NSArray *)getInsertSql:(DBModel *)model
{
    NSString *tableName = [self tableName];
    NSMutableString *keyString = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];
    for (int i = 0; i < model.columeNames.count; i++) {
        NSString *proname = [model.columeNames objectAtIndex:i];
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        id value = NIl_STR([model valueForKey:proname]);
        [insertValues addObject:value];
    }
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
    return @[sql,insertValues];
}


- (NSString *)description
{
    NSString *result = @"";
    NSDictionary *dict = [self.class getAllProperties];
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    for (int i = 0; i < proNames.count; i++) {
        NSString *proName = [proNames objectAtIndex:i];
        id  proValue = [self valueForKey:proName];
        result = [result stringByAppendingFormat:@"%@:%@\n",proName,proValue];
    }
    return result;
}

#pragma mark - 子类重写的方法(忽略字段和设置主键)
/** 如果子类中有一些property不需要创建数据库字段，那么这个方法必须在子类中重写
 */
+ (NSArray *)ignoredProperty
{
    return @[@"columeNames",@"columeTypes"];
}

/** 子类重写此方法设置主键
 */
+ (NSString *)primaryKey
{
    return nil;
}

+ (NSString *)tableName
{
    return NSStringFromClass(self);
}

@end
