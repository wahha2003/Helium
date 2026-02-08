#import <Foundation/Foundation.h>
#import "../helpers/private_headers/MediaRemote.h"

@interface MediaRemoteManager : NSObject

+ (instancetype)sharedManager;

- (void)getNowPlayingInfoWithCompletion:(void (^)(NSDictionary *info))completion;
- (void)getBundleIdentifierWithCompletion:(void (^)(NSString *bundleIdentifier))completion;
- (void)getNowPlayingApplicationIsPlayingWithCompletion:(void (^)(bool isPlaying))completion;

@end
