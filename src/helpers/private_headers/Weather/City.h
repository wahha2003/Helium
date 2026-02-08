@class WFAQIScaleCategory, WFTemperature;

@interface City : NSObject
@property (nonatomic, retain) WFTemperature *temperature;
@property(nonatomic) NSInteger conditionCode;
@property (nonatomic, copy) NSArray *dayForecasts;
@property (nonatomic, copy) NSArray *hourlyForecasts;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, retain) WFTemperature *feelsLike;
@property (nonatomic, retain) WFAQIScaleCategory *airQualityScaleCategory;
@property (nonatomic, assign) BOOL isDay;  
- (NSString *)naturalLanguageDescription;
- (NSString *)naturalLanguageDescriptionWithDescribedCondition:(out NSInteger *)condition;
- (NSDate *)updateTime;
- (NSString *)displayName;
- (WFTemperature *)temperature;
- (NSString *)detailedDescription;
@end