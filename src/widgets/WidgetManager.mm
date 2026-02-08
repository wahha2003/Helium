//
//  WidgetManager.m
//  
//
//  Created by lemin on 10/6/23.
//

#import <Foundation/Foundation.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <sys/wait.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import "WidgetManager.h"
#import <IOKit/IOKitLib.h>
#import <AVFoundation/AVAudioSession.h>
#import "../extensions/LunarDate.h"
#import "../extensions/FontUtils.h"
#import "../extensions/WeatherUtils.h"
#import "../extensions/HWeatherController.h"
#import "../extensions/HFPSStatus.h"
#import "../extensions/MediaRemoteManager.h"

// Thanks to: https://github.com/lwlsw/NetworkSpeed13

#define KILOBITS 1000
#define MEGABITS 1000000
#define GIGABITS 1000000000
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define SHOW_ALWAYS 1
// #define INLINE_SEPARATOR "\t"

// #pragma mark - Formatting Methods
// static unsigned char getSeparator(NSMutableAttributedString *currentAttributed)
// {
//     return [[currentAttributed string] isEqualToString:@""] ? *"" : *"\t";
// }

#pragma mark - Widget-specific Variables
// MARK: 0 - Date Widget
static NSDateFormatter *formatter = nil;

// MARK: Net Speed Widget
static uint8_t DATAUNIT = 0;

typedef struct {
    uint64_t inputBytes;
    uint64_t outputBytes;
} UpDownBytes;

static uint64_t prevOutputBytes = 0, prevInputBytes = 0;
static NSAttributedString *attributedUploadPrefix = nil;
static NSAttributedString *attributedDownloadPrefix = nil;
static NSAttributedString *attributedUploadPrefix2 = nil;
static NSAttributedString *attributedDownloadPrefix2 = nil;

#pragma mark - Date Widget
static NSString* formattedDate(NSString *dateFormat, NSString* dateLocale)
{
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:dateLocale];
    }
    NSDate *currentDate = [NSDate date];
    NSString *newDateFormat = [LunarDate getChineseCalendarWithDate:currentDate format:dateFormat];
    [formatter setDateFormat:newDateFormat];
    return [formatter stringFromDate:currentDate];
}

#pragma mark - Net Speed Widgets
static UpDownBytes getUpDownBytes()
{
    struct ifaddrs *ifa_list = 0, *ifa;
    UpDownBytes upDownBytes;
    upDownBytes.inputBytes = 0;
    upDownBytes.outputBytes = 0;
    
    if (getifaddrs(&ifa_list) == -1) return upDownBytes;

    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        /* Skip invalid interfaces */
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL || ifa->ifa_data == NULL)
            continue;
        
        /* Skip interfaces that are not link level interfaces */
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;

        /* Skip interfaces that are not up or running */
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        
        /* Skip interfaces that are not ethernet or cellular */
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6))
            continue;
        
        struct if_data *if_data = (struct if_data *)ifa->ifa_data;
        
        upDownBytes.inputBytes += if_data->ifi_ibytes;
        upDownBytes.outputBytes += if_data->ifi_obytes;
    }
    
    freeifaddrs(ifa_list);
    return upDownBytes;
}

static NSString* formattedSpeed(uint64_t bytes, NSInteger minUnit)
{
    if (0 == DATAUNIT) {
        // Get min units first
        if (minUnit == 1 && bytes < KILOBYTES) return @"0 KB/s";
        else if (minUnit == 2 && bytes < MEGABYTES) return @"0 MB/s";
        else if (minUnit == 3 && bytes < GIGABYTES) return @"0 GB/s";

        if (bytes < KILOBYTES) return [NSString stringWithFormat:@"%.0f B/s", (double)bytes];
        else if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.0f KB/s", (double)bytes / KILOBYTES];
        else if (bytes < GIGABYTES) return [NSString stringWithFormat:@"%.2f MB/s", (double)bytes / MEGABYTES];
        else return [NSString stringWithFormat:@"%.2f GB/s", (double)bytes / GIGABYTES];
    } else {
        // Get min units first
        if (minUnit == 1 && bytes < KILOBITS) return @"0 Kb/s";
        else if (minUnit == 2 && bytes < MEGABITS) return @"0 Mb/s";
        else if (minUnit == 3 && bytes < GIGABITS) return @"0 Gb/s";

        if (bytes < KILOBITS) return [NSString stringWithFormat:@"%.0f b/s", (double)bytes];
        else if (bytes < MEGABITS) return [NSString stringWithFormat:@"%.0f Kb/s", (double)bytes / KILOBITS];
        else if (bytes < GIGABITS) return [NSString stringWithFormat:@"%.2f Mb/s", (double)bytes / MEGABITS];
        else return [NSString stringWithFormat:@"%.2f Gb/s", (double)bytes / GIGABITS];
    }
}

static NSAttributedString* formattedAttributedSpeedString(BOOL isUp, NSInteger speedIcon, NSInteger minUnit, BOOL hideWhenZero, double fontSize)
{
    @autoreleasepool {
        if (!attributedUploadPrefix)
            attributedUploadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"▲"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedDownloadPrefix)
            attributedDownloadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"▼"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedUploadPrefix2)
            attributedUploadPrefix2 = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"↑"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedDownloadPrefix2)
            attributedDownloadPrefix2 = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"↓"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        
        NSMutableAttributedString* mutableString = [[NSMutableAttributedString alloc] init];
        
        UpDownBytes upDownBytes = getUpDownBytes();
        
        uint64_t diff;
        
        if (isUp) {
            if (upDownBytes.outputBytes > prevOutputBytes)
                diff = upDownBytes.outputBytes - prevOutputBytes;
            else
                diff = 0;
            prevOutputBytes = upDownBytes.outputBytes;
        } else {
            if (upDownBytes.inputBytes > prevInputBytes)
                diff = upDownBytes.inputBytes - prevInputBytes;
            else
                diff = 0;
            prevInputBytes = upDownBytes.inputBytes;
        }
        
        if (DATAUNIT == 1)
            diff *= 8;
        
        NSString *speedString = formattedSpeed(diff, minUnit);
        if (!hideWhenZero || ![speedString hasPrefix:@"0"]) {
            if (isUp)
                [mutableString appendAttributedString:(speedIcon == 0 ? attributedUploadPrefix : attributedUploadPrefix2)];
            else
                [mutableString appendAttributedString:(speedIcon == 0 ? attributedDownloadPrefix : attributedDownloadPrefix2)];
            [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:speedString]];
        }
        
        return [mutableString copy];
    }
}

#pragma mark - Battery Temp Widget
NSDictionary* getBatteryInfo()
{
    CFDictionaryRef matching = IOServiceMatching("IOPMPowerSource");
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    CFMutableDictionaryRef prop = NULL;
    IORegistryEntryCreateCFProperties(service, &prop, NULL, 0);
    NSDictionary* dict = (__bridge_transfer NSDictionary*)prop;
    IOObjectRelease(service);
    return dict;
}

static NSString* formattedTemp(BOOL useFahrenheit)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        // AdapterDetails.Watts.Description.Temperature
        double temp = [batteryInfo[@"Temperature"] doubleValue] / 100.0;
        if (temp) {
            if (useFahrenheit) {
                temp = (temp * 9.0/5.0) + 32;
                return [NSString stringWithFormat: @"%.2fºF", temp];
            } else {
                return [NSString stringWithFormat: @"%.2fºC", temp];
            }
        }
    }
    return @"??ºC";
}

#pragma mark - Battery Widget
/*
 Battery Widget Identifiers:
 0 = Watts
 1 = Charging Current
 2 = Regular Amperage
 3 = Charge Cycles
 */
static NSString* formattedBattery(NSInteger valueType)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        if (valueType == 0) {
            // Watts
            int watts = [batteryInfo[@"AdapterDetails"][@"Watts"] longLongValue];
            if (watts) {
                return [NSString stringWithFormat: @"%d W", watts];
            } else {
                return @"0 W";
            }
        } else if (valueType == 1) {
            // Charging Current
            double current = [batteryInfo[@"AdapterDetails"][@"Current"] doubleValue];
            if (current) {
                return [NSString stringWithFormat: @"%.0f mA", current];
            } else {
                return @"0 mA";
            }
        } else if (valueType == 2) {
            // Regular Amperage
            double amps = [batteryInfo[@"Amperage"] doubleValue];
            if (amps) {
                return [NSString stringWithFormat: @"%.0f mA", amps];
            } else {
                return @"0 mA";
            }
        } else if (valueType == 3) {
            // Charge Cycles
            return [batteryInfo[@"CycleCount"] stringValue];
        } else {
            return @"???";
        }
    }
    return @"??";
}

#pragma mark - Current Capacity Widget
static NSString* formattedCurrentCapacity(BOOL showPercentage)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        return [
            NSString stringWithFormat: @"%@%@",
            [batteryInfo[@"CurrentCapacity"] stringValue],
            showPercentage ? @"%" : @""
            ];
    }
    return @"??%";
}

#pragma mark - Charging Symbol Widget
static NSString* formattedChargingSymbol(BOOL filled)
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled: YES];
    if ([[UIDevice currentDevice] batteryState] != UIDeviceBatteryStateUnplugged) {
        if (filled) {
            return @"bolt.fill";
        } else {
            return @"bolt";
        }
    }
    return @"";
}


static NSMutableAttributedString* replaceWeatherImage(NSString* formattedText, NSAttributedString *replacement) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\{([^}]+)\\}" options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSArray *matches = [regex matchesInString:formattedText options:kNilOptions range:NSMakeRange(0, formattedText.length)];
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:formattedText];
    for (NSTextCheckingResult *result in [matches reverseObjectEnumerator])
    {
        NSString *match = [formattedText substringWithRange:result.range];
        if ([match isEqual:@"{i}"]) {
            [attributedString replaceCharactersInRange:result.range withAttributedString:replacement];
        }
    }
    return attributedString;
}

static BOOL hasBluetoothHeadset() {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *currentRoute = [audioSession currentRoute];
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        if ([[output portType] isEqualToString:@"BluetoothA2DPOutput"]) {
            return YES;
        }
    }
    return NO;
}

static NSString* getLyricsKeyByBundleIdentifier(NSString *bundleid) {
    if([bundleid isEqual:@"com.soda.music"]
        || [bundleid isEqual:@"com.tencent.QQMusic"] 
        || [bundleid isEqual:@"com.yeelion.kwplayer"]
        || [bundleid isEqual:@"com.migu.migumobilemusic"]
        || [bundleid isEqual:@"com.wenyu.bodian"]
    ) {
        if (!hasBluetoothHeadset()) {
            return @"kMRMediaRemoteNowPlayingInfoArtist";
        } else {
            return @"kMRMediaRemoteNowPlayingInfoTitle";
        }
    } else if([bundleid isEqual:@"com.netease.cloudmusic"]
        || [bundleid isEqual:@"com.kugou.kugou1002"]
        || [bundleid isEqual:@"com.kugou.kgyouth"]
    ) {
        return @"kMRMediaRemoteNowPlayingInfoTitle";
    } else {
        return nil;
    }
}

static NSString* getLyricsKeyByType(int type) {
    if(type == 1) {
        return @"kMRMediaRemoteNowPlayingInfoTitle";
    } else if(type == 2) {
        return @"kMRMediaRemoteNowPlayingInfoArtist";
    } else if(type == 3) {
        return @"kMRMediaRemoteNowPlayingInfoAlbum";
    } else {
        return nil;
    }
}

#pragma mark - Main Widget Functions
/*
 Widget Identifiers:
 0 = None
 1 = Date
 2 = Network Up/Down
 3 = Device Temp
 4 = Battery Detail
 5 = Time
 6 = Text
 7 = Battery Percentage
 8 = Charging Symbol
 9 = Weather
 10 = Lyrics
 11 = FPS

 TODO:
 - Music Visualizer
 */
void formatParsedInfo(NSDictionary *parsedInfo, NSInteger parsedID, NSMutableAttributedString *mutableString, double fontSize, UIColor *textColor, UIFont *font, NSString *dateLocale)
{
    NSString *widgetString;
    NSString *sfSymbolName;
    NSTextAttachment *imageAttachment;
    switch (parsedID) {
        case 1:
        case 5:
            // Date/Time
            widgetString = formattedDate(
                [parsedInfo valueForKey:@"dateFormat"] ? [parsedInfo valueForKey:@"dateFormat"] : (parsedID == 1 ? NSLocalizedString(@"E MMM dd", comment: @"") : @"hh:mm"),
                dateLocale
            );
            break;
        case 2:
            // Network Speed
            [
                mutableString appendAttributedString: formattedAttributedSpeedString(
                    [parsedInfo valueForKey:@"isUp"] ? [[parsedInfo valueForKey:@"isUp"] boolValue] : NO,
                    [parsedInfo valueForKey:@"speedIcon"] ? [[parsedInfo valueForKey:@"speedIcon"] intValue] : 0,
                    [parsedInfo valueForKey:@"minUnit"] ? [[parsedInfo valueForKey:@"minUnit"] intValue] : 1,
                    [parsedInfo valueForKey:@"hideSpeedWhenZero"] ? [[parsedInfo valueForKey:@"hideSpeedWhenZero"] boolValue] : NO,
                    fontSize
                )
            ];
            break;
        case 3:
            // Device Temp
            widgetString = formattedTemp(
                [parsedInfo valueForKey:@"useFahrenheit"] ? [[parsedInfo valueForKey:@"useFahrenheit"] boolValue] : NO
            );
            break;
        case 4:
            // Battery Stats
            widgetString = formattedBattery(
                [parsedInfo valueForKey:@"batteryValueType"] ? [[parsedInfo valueForKey:@"batteryValueType"] integerValue] : 0
            );
            break;
        case 6:
            // Text
            widgetString = [parsedInfo valueForKey:@"text"] ? [parsedInfo valueForKey:@"text"] : @"Unknown";
            break;
        case 7:
            // Current Capacity
            widgetString = formattedCurrentCapacity(
                [parsedInfo valueForKey:@"showPercentage"] ? [[parsedInfo valueForKey:@"showPercentage"] boolValue] : YES
            );
            break;
        case 8:
            // Charging Symbol
            sfSymbolName = formattedChargingSymbol(
                [parsedInfo valueForKey:@"filled"] ? [[parsedInfo valueForKey:@"filled"] boolValue] : YES
            );
            if (![sfSymbolName isEqualToString:@""]) {
                imageAttachment = [[NSTextAttachment alloc] init];
                imageAttachment.image = [
                    [
                        UIImage systemImageNamed:sfSymbolName
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:fontSize]
                    ]
                    imageWithTintColor:textColor
                ];
                [mutableString appendAttributedString:[NSAttributedString attributedStringWithAttachment:imageAttachment]];
            }
            break;
        case 9:
            {
                // Weather
                NSString *format = [parsedInfo valueForKey:@"format"] ?: @"{i}{n}{lt}°~{ht}°({t}°,{bt}°)💧{h}%";
                HWeatherController *weatherController = [HWeatherController sharedInstance];
                weatherController.locale = [[NSLocale alloc] initWithLocaleIdentifier:dateLocale];
                [weatherController updateModel];
                weatherController.useFahrenheit = [parsedInfo valueForKey:@"useFahrenheit"] ? [[parsedInfo valueForKey:@"useFahrenheit"] boolValue] : NO;
                weatherController.useMetric = [parsedInfo valueForKey:@"useMetric"] ? [[parsedInfo valueForKey:@"useMetric"] boolValue] : NO;
                NSDictionary *weatherData = [weatherController weatherData];
                format = [WeatherUtils formatWeatherData:weatherData format:format];
                // NSLog(@"boom format:%@", format);

                UIImage *weatherImage = weatherData[@"conditions_image"];
                if (weatherImage) {
                    imageAttachment = [[NSTextAttachment alloc] init];
                    CGFloat imgH = font.pointSize * 1.4f;
                    CGFloat imgW = (weatherImage.size.width / weatherImage.size.height) * imgH;
                    [imageAttachment setBounds:CGRectMake(0, roundf(font.capHeight - imgH)/2.f, imgW, imgH)];
                    weatherImage = [weatherImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    imageAttachment.image = weatherImage;
                    format = [format stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
                    format = [format stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
                    [mutableString appendAttributedString:replaceWeatherImage(format, [NSAttributedString attributedStringWithAttachment:imageAttachment])];
                } else {
                    widgetString = format;
                }
            }
            break;
        case 10:
            {
                // Lyrics
                int lyricsType = [parsedInfo valueForKey:@"lyricsType"] ? [[parsedInfo valueForKey:@"lyricsType"] integerValue] : 0;
                int bluetoothType = [parsedInfo valueForKey:@"bluetoothType"] ? [[parsedInfo valueForKey:@"bluetoothType"] integerValue] : 0;
                bool unsupported = [parsedInfo valueForKey:@"unsupported"] ? [[parsedInfo valueForKey:@"unsupported"] boolValue] : NO;

                __block NSString *resultMessage1 = nil;
                __block BOOL resultMessage2 = false;
                __block NSString *resultMessage3 = nil;
                MediaRemoteManager *manager = [MediaRemoteManager sharedManager];
                dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                if (!unsupported) {
                    [manager getBundleIdentifierWithCompletion:^(NSString *bundleIdentifier) {
                        resultMessage1 = getLyricsKeyByBundleIdentifier(bundleIdentifier);
                        dispatch_semaphore_signal(semaphore);
                    }];
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                }
                if (unsupported || resultMessage1) {
                    [manager getNowPlayingApplicationIsPlayingWithCompletion:^(BOOL isPlaying) {
                        resultMessage2 = isPlaying;
                        dispatch_semaphore_signal(semaphore);
                    }];
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                    if (resultMessage2) {
                        [manager getNowPlayingInfoWithCompletion:^(NSDictionary *info) {
                            if (lyricsType == 0 && resultMessage1) {
                                resultMessage3 = info[resultMessage1];
                            } else {
                                if (hasBluetoothHeadset()) {
                                    resultMessage3 = info[getLyricsKeyByType(bluetoothType)];
                                } else {
                                    resultMessage3 = info[getLyricsKeyByType(lyricsType)];
                                }
                            }
                            dispatch_semaphore_signal(semaphore);
                        }];
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                        widgetString = resultMessage3;
                    }
                }
            }
            break;
        case 11:
            {
                widgetString = [NSString stringWithFormat: @"%.0f FPS", [HFPSStatus sharedInstance].fpsValue];
            }
            break;
        default:
            // do not add anything
            break;
    }
    if (widgetString) {
        widgetString = [widgetString stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
        widgetString = [widgetString stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
        [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString: widgetString]];
    }
}

NSAttributedString* formattedAttributedString(NSArray *identifiers, double fontSize, UIColor *textColor, UIFont *font, NSString *dateLocale)
{
    @autoreleasepool {
        NSMutableAttributedString* mutableString = [[NSMutableAttributedString alloc] init];
        dispatch_queue_t concurrentQueue = dispatch_queue_create("formatqueue", DISPATCH_QUEUE_CONCURRENT);

        if (identifiers) {
            for (id idInfo in identifiers) {
                dispatch_sync(concurrentQueue, ^{
                    NSDictionary *parsedInfo = idInfo;
                    NSInteger parsedID = [parsedInfo valueForKey:@"widgetID"] ? [[parsedInfo valueForKey:@"widgetID"] integerValue] : 0;
                    formatParsedInfo(parsedInfo, parsedID, mutableString, fontSize, textColor, font, dateLocale);
                });
            }
        } else {
            return nil;
        }
        
        return [mutableString copy];
    }
}
