@class City;

@interface WeatherPreferences : NSObject
+ (instancetype)sharedPreferences;
- (City *)localWeatherCity;
-(int)loadActiveCity;
-(NSArray *)loadSavedCities;
+(id)userDefaultsPersistence;
-(NSDictionary *)userDefaults;
-(void)setLocalWeatherEnabled:(BOOL)arg1;
-(City *)cityFromPreferencesDictionary:(id)arg1;
-(BOOL)isCelsius;
-(BOOL)isLocalWeatherEnabled;
@property (assign,setter=setLocalWeatherEnabled:,getter=isLocalWeatherEnabled,nonatomic) BOOL isLocalWeatherEnabled; 
@end