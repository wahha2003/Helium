@interface WeatherWindSpeedFormatter : NSFormatter
+(id)convenienceFormatter;
-(NSString *)stringForWindSpeed:(float)arg1 ;
-(NSString *)stringForWindDirection:(float)arg1 shortDescription:(BOOL)arg2 ;
-(NSString *)formattedStringForSpeed:(float)arg1 direction:(float)arg2 shortDescription:(BOOL)arg3 ;
-(NSString *)speedStringByConvertingToUserUnits:(float)arg1 ;
-(NSString *)fallbackStringForWindSpeed:(float)arg1 ;
-(NSString *)fallbackUnitString;
-(int)windSpeedUnit;
-(void)setLocale:(NSLocale *)arg1 ;
@end