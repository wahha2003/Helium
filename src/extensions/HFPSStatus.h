#import <Foundation/Foundation.h>
#import <mach/mach.h>

// 声明 QuartzCore 私有 API
extern "C" {
    int CARenderServerGetDebugOption(mach_port_t port, int key);
    int CARenderServerGetDebugValue(mach_port_t port, int key);
    void CARenderServerSetDebugOption(mach_port_t port, int key, int value);
    void CARenderServerSetDebugValue(mach_port_t port, int key, int value);
}

// 核心常量
#define CA_DEBUG_OPTION_PERF_HUD 0x24

typedef NS_ENUM(NSInteger, CAPerfHUDLevel) {
    CAPerfHUDLevelOff = 0,
    CAPerfHUDLevelBasic = 1,
    CAPerfHUDLevelBackdrop = 2,
    CAPerfHUDLevelParticles = 3,
    CAPerfHUDLevelFull = 4,
    CAPerfHUDLevelFrequencies = 5,
    CAPerfHUDLevelPower = 6,
    CAPerfHUDLevelFPSOnly = 7,
    CAPerfHUDLevelDisplay = 8,
    CAPerfHUDLevelGlitches = 9
};

@interface HFPSStatus : NSObject
+ (void)setPerfHUDLevel:(CAPerfHUDLevel)level;
+ (CAPerfHUDLevel)currentPerfHUDLevel;
@end
