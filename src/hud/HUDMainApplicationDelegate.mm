#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "HUDRootViewController.h"

#import "../extensions/FontUtils.h"
#import "../extensions/HWeatherController.h"

#import "../helpers/private_headers/SBSAccessibilityWindowHostingController.h"
#import "../helpers/private_headers/UIWindow+Private.h"

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
    SBSAccessibilityWindowHostingController *_windowHostingController;
}

- (instancetype)init
{
    if (self = [super init])
    {
#if DEBUG
        os_log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate init]");
#endif

        // load fonts from app
        [FontUtils loadFontsFromFolder:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] resourcePath],  @"/fonts"]];
        // load fonts from documents
        [FontUtils loadFontsFromFolder:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]];

        // set language
        // [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLanguages"];
        // [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLocale"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObjects: [self dateLocale], nil] forKey:@"AppleLanguages"];
        // [[NSUserDefaults standardUserDefaults] setObject:[self dateLocale] forKey:@"AppleLocale"];

        [[NSUserDefaults standardUserDefaults] synchronize];

        [HWeatherController sharedInstance];
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary <UIApplicationLaunchOptionsKey, id> *)launchOptions
{
#if DEBUG
    os_log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate application:%{public}@ didFinishLaunchingWithOptions:%{public}@]", application, launchOptions);
#endif

    _rootViewController = [[HUDRootViewController alloc] init];

    self.window = [[HUDMainWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window setRootViewController:_rootViewController];
    
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    _windowHostingController = [[objc_getClass("SBSAccessibilityWindowHostingController") alloc] init];
    unsigned int _contextId = [self.window _contextId];
    double windowLevel = [self.window windowLevel];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // [_windowHostingController registerWindowWithContextID:_contextId atLevel:windowLevel];
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:_windowHostingController];
    [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
    [invocation setArgument:&_contextId atIndex:2];
    [invocation setArgument:&windowLevel atIndex:3];
    [invocation invoke];
#pragma clang diagnostic pop

    return YES;
}

- (NSString*) dateLocale
{
    NSDictionary *_userDefaults = [[NSDictionary dictionaryWithContentsOfFile:USER_DEFAULTS_PATH] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *locale = [_userDefaults objectForKey: @"dateLocale"];
    return locale ? locale : @"en";
}

@end