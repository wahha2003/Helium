// https://github.com/DGh0st/HSWidgets
#import "../helpers/private_headers/Weather/WeatherHeaders.h"

@class City, WATodayModel;

@interface HWeatherController : NSObject
@property (nonatomic, strong) WALockscreenWidgetViewController *widgetVC;
@property (nonatomic, strong) City *myCity;
@property (nonatomic, strong) WATodayModel *todayModel;
@property (nonatomic, retain) NSBundle *weatherBundle;
@property (nonatomic) BOOL useFahrenheit;
@property (nonatomic) BOOL useMetric;
@property (nonatomic) NSLocale *locale;

+(instancetype)sharedInstance;
-(NSString *)locationName;
-(UIImage *)conditionsImage;
-(NSString *)conditionsImageName;
-(NSString *)conditionsDescription;
-(NSString *)temperature;
-(NSString *)temperature:(BOOL) withSymbol;
-(NSString *)feelsLike;
-(NSString *)feelsLike:(BOOL) withSymbol;
-(NSString *)highDescription;
-(NSString *)highDescription:(BOOL) withSymbol;
-(NSString *)lowDescription;
-(NSString *)lowDescription:(BOOL) withSymbol;
-(NSString *)windSpeed;
-(NSString *)windSpeed:(BOOL) withUnit;
-(NSString *)windDirection;
-(NSString *)windDirection:(BOOL) shortDescription;
-(NSString *)humidity;
-(NSString *)humidity:(BOOL) withSymbol;
-(NSString *)visibility;
-(NSString *)visibility:(BOOL) withUnit;
-(NSString *)pressure;
-(NSString *)pressure:(BOOL) withUnit;
-(NSString *)UVIndex;
-(NSString *)precipitation;
-(NSString *)precipitation:(BOOL) withUnit;
-(NSString *)airQualityIndex;
-(NSDictionary *)weatherData;

-(void)updateModel;
@end