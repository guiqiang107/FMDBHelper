# FMDBHelper
/**
 *  数据库对象的父类
 */
@interface DBModel : NSObject

/** 插入或更新本地数据库的时间戳 */
@property (nonatomic, assign) NSTimeInterval timestamp;

/** 是否存在表 */
+ (BOOL)isExistTable;

/** 建表 */
+ (BOOL)createTable;

/** 清空表 */
+ (BOOL)clearTable;

/**
 *批量保存或更新数据
 *存在主键,直接根据主键查询,若查询出记录,则更新;若无记录,则插入
 *不存在主键,全部插入
 */
+ (BOOL)saveOrUpdateObjects:(NSArray *)array;

/**
 *根据条件更新数据
 */
+ (BOOL)updateObj:(DBModel *)model condition:(NSString *)condition;

/** 通过条件删除数据
 * condition为sql where后的语句,不能为nil
 */
+ (BOOL)deleteObjByCondition:(NSString *)condition;

/** 批量删除数据
 *根据主键删除(必须设置主键才能调用)
 */
+ (BOOL)deleteObjects:(NSArray *)array;

/** 根据主键查询是否存在某条数据(查询类名那张表)
 */
+ (BOOL)isExits:(DBModel *)model;

/** 根据条件查找第一条数据（condition为sql where后的语句）
 */
+ (id)findFirstObjByCondition:(NSString *)condition;

/** 根据条件查找数据（condition为sql where后的语句）
 *  condition = nil表示查询全部数据
 */
+ (NSArray *)findObjsByCondition:(NSString *)condition;

/** 查询总条数
 */
+ (NSInteger)findAllCounts;


#pragma mark - 子类重新方法
/** 如果子类中有一些property不需要创建数据库字段，那么这个方法必须在子类中重写
 */
+ (NSArray *)ignoredProperty;

/** 子类重写此方法设置主键
 */
+ (NSString *)primaryKey;

/**
 模型对应的数据库表
 */
+ (NSString *)tableName;
