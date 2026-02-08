#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface HFPSStatus : NSObject

@property (nonatomic)float fpsValue;

+ (HFPSStatus *)sharedInstance;

@end