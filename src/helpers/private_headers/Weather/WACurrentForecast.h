@class WFTemperature;

@interface WACurrentForecast : NSObject // iOS 10 - 13
@property (nonatomic,retain) WFTemperature * temperature;
@property (nonatomic,retain) WFTemperature * feelsLike;
@property (assign,nonatomic) float windSpeed;
@property (assign,nonatomic) float windDirection;
@property (assign,nonatomic) float humidity;
@property (assign,nonatomic) float dewPoint;
@property (assign,nonatomic) float visibility;
@property (assign,nonatomic) float pressure;
@property (assign,nonatomic) unsigned long long pressureRising;
@property (assign,nonatomic) unsigned long long UVIndex;
@property (assign,nonatomic) float precipitationPast24Hours;
@property (assign,nonatomic) NSInteger conditionCode;
@property (assign,nonatomic) unsigned long long observationTime;
@end
