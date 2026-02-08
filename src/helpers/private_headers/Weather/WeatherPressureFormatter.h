@interface WeatherPressureFormatter : NSFormatter

+(id)convenienceFormatter;
-(void)setLocale:(NSLocale *)arg1 ;
-(NSString *)stringFromMillibars:(float)arg1 ;
-(NSString *)stringFromInchesHG:(float)arg1 ;
@end