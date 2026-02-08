@interface WeatherVisibilityFormatter : NSLengthFormatter
+(id)convenienceFormatter;
-(id)stringFromKilometers:(double)arg1 ;
-(id)stringFromMiles:(double)arg1 ;
-(id)stringFromDistance:(double)arg1 isDataMetric:(BOOL)arg2 ;
-(void)setLocale:(NSLocale *)arg1 ;
@end