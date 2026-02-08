#import "MediaRemoteManager.h"

@implementation MediaRemoteManager

+ (instancetype)sharedManager {
    static MediaRemoteManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)getNowPlayingInfoWithCompletion:(void (^)(NSDictionary *info))completion {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        NSDictionary *info = (__bridge NSDictionary*)information;
        completion(info);
    });
}

- (void)getBundleIdentifierWithCompletion:(void (^)(NSString *bundleIdentifier))completion {
    MRMediaRemoteGetNowPlayingClient(dispatch_get_main_queue(), ^(id client) {
        // NSLog(@"boom: %@", client);
        CFStringRef bundleid = MRNowPlayingClientGetBundleIdentifier(client);
        NSString *bundleIdentifier = (__bridge NSString*)bundleid;
        completion(bundleIdentifier);
    });
}

- (void)getNowPlayingApplicationIsPlayingWithCompletion:(void (^)(bool isPlaying))completion {
    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlaying) {
        // NSLog(@"boom: %d", isPlaying);
        completion(isPlaying);
    });
}

@end
