@interface WeatherPrecipitationFormatter : NSLengthFormatter

+(id)convenienceFormatter;
-(id)stringFromInches:(double)arg1 ;
-(id)stringFromCentimeters:(double)arg1 ;
-(id)stringFromDistance:(double)arg1 isDataMetric:(BOOL)arg2 ;
-(void)setLocale:(NSLocale *)arg1 ;
@end