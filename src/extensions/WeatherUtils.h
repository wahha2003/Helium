#import <Foundation/Foundation.h>
#import <Foundation/NSBundle.h>
#import <CoreText/CoreText.h>
#import <UIKit/UIKit.h>

@interface WeatherUtils : NSObject
+ (NSString *)getWeatherIcon:(NSString *)text;
+ (NSString*)formatWeatherData:(NSDictionary *)data format:(NSString *)format;
@end