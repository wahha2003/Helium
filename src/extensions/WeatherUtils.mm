#import "WeatherUtils.h"

@implementation WeatherUtils

+ (NSString *)getWeatherIcon:(NSString *)text {
    NSString *weatherIcon = @"🌤️";
    NSArray *weatherIconList = @[@"☀️", @"☁️", @"⛅️",
                                 @"☃️", @"⛈️", @"🏜️", @"🏜️", @"🌫️", @"🌫️", @"🌪️", @"🌧️"];
    NSArray *weatherType = @[@"晴|sunny", @"阴|overcast", @"云|cloudy", @"雪|snow", @"雷|thunder", @"沙|sand", @"尘|dust", @"雾|foggy", @"霾|haze", @"风|wind", @"雨|rain"];
    
    NSRegularExpression *regex;
    for (int i = 0; i < weatherType.count; i++) {
        NSString *pattern = [NSString stringWithFormat:@".*%@.*", weatherType[i]];
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
        if ([regex numberOfMatchesInString:text options:0 range:NSMakeRange(0, [text length])] > 0) {
            weatherIcon = weatherIconList[i];
            break;
        }
    }
    
    return weatherIcon;
}

+ (NSString*)formatWeatherData:(NSDictionary *)data format:(NSString *)format {
    if(data) {
        @try {
            format = [format stringByReplacingOccurrencesOfString:@"{n}" withString:data[@"conditions"]];
            format = [format stringByReplacingOccurrencesOfString:@"{l}" withString:data[@"location"]];
            format = [format stringByReplacingOccurrencesOfString:@"{uvi}" withString:data[@"uv_index"]];
            format = [format stringByReplacingOccurrencesOfString:@"{aqi}" withString:data[@"aqi"]];

            format = [format stringByReplacingOccurrencesOfString:@"{t}" withString:data[@"temperature"]];
            format = [format stringByReplacingOccurrencesOfString:@"{ts}" withString:data[@"temperature_with_symbol"]];

            format = [format stringByReplacingOccurrencesOfString:@"{bt}" withString:data[@"feels_like"]];
            format = [format stringByReplacingOccurrencesOfString:@"{bts}" withString:data[@"feels_like_with_symbol"]];

            format = [format stringByReplacingOccurrencesOfString:@"{lt}" withString:data[@"low_temperature"]];
            format = [format stringByReplacingOccurrencesOfString:@"{lts}" withString:data[@"low_temperature_with_symbol"]];

            format = [format stringByReplacingOccurrencesOfString:@"{ht}" withString:data[@"high_temperature"]];
            format = [format stringByReplacingOccurrencesOfString:@"{hts}" withString:data[@"high_temperature_with_symbol"]];
            
            format = [format stringByReplacingOccurrencesOfString:@"{ws}" withString:data[@"wind_speed"]];
            format = [format stringByReplacingOccurrencesOfString:@"{wsu}" withString:data[@"wind_speed_with_unit"]];

            format = [format stringByReplacingOccurrencesOfString:@"{wd}" withString:data[@"wind_direction"]];
            format = [format stringByReplacingOccurrencesOfString:@"{wds}" withString:data[@"wind_direction_short"]];

            format = [format stringByReplacingOccurrencesOfString:@"{h}" withString:data[@"humidity"]];
            format = [format stringByReplacingOccurrencesOfString:@"{hs}" withString:data[@"humidity_with_symbol"]];

            format = [format stringByReplacingOccurrencesOfString:@"{v}" withString:data[@"visibility"]];
            format = [format stringByReplacingOccurrencesOfString:@"{vu}" withString:data[@"visibility_with_unit"]];
            
            format = [format stringByReplacingOccurrencesOfString:@"{pp}" withString:data[@"precipitation"]];
            format = [format stringByReplacingOccurrencesOfString:@"{ppu}" withString:data[@"precipitation_with_unit"]];

            format = [format stringByReplacingOccurrencesOfString:@"{ps}" withString:data[@"pressure"]];
            format = [format stringByReplacingOccurrencesOfString:@"{psu}" withString:data[@"pressure_with_unit"]];
        }
        @catch (NSException *exception) {
            NSLog(@"[ERROR]\nstr[%@]\nexception[%@]", format, exception);
            format = NSLocalizedString(@"error", comment:@"");
        }
    } else {
        format = NSLocalizedString(@"error", comment:@"");
    }
    return format;
}

@end