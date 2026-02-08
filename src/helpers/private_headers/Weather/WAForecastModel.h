@class City, WACurrentForecast, WFLocation, WFAirQualityConditions;

@interface WAForecastModel : NSObject // iOS 10 - 13
@property (nonatomic, retain) City *city; // iOS 10 - 13
@property (nonatomic, retain) WFLocation *location; // iOS 10 - 13
@property (nonatomic, retain) WACurrentForecast *currentConditions; // iOS 10 - 13
@property (nonatomic, retain) WFAirQualityConditions * airQualityConditions; 
@property (nonatomic, copy) NSArray *dailyForecasts; // iOS 10 - 13
@property (nonatomic, copy) NSArray *hourlyForecasts; // iOS 10 - 13
@end