@interface WeatherImageLoader : NSObject
+ (id)sharedImageLoader;
+ (id)conditionImageBundle;
+ (id)conditionImageNamed:(NSString *)name;
+ (id)conditionImageWithConditionIndex:(NSInteger)conditionCode;
+ (id)conditionImageNameWithConditionIndex:(NSInteger)conditionCode;
@end