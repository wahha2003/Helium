#import "HFPSStatus.h"

@interface HFPSStatus (){
    CADisplayLink *displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _tickCount;
}
@end

@implementation HFPSStatus

// - (void)dealloc {
//     [displayLink setPaused:YES];
//     [displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
// }

+ (HFPSStatus *)sharedInstance {
    static HFPSStatus *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HFPSStatus alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        // [[NSNotificationCenter defaultCenter] addObserver: self
        //                                          selector: @selector(applicationDidBecomeActiveNotification)
        //                                              name: UIApplicationDidBecomeActiveNotification
        //                                            object: nil];
        
        // [[NSNotificationCenter defaultCenter] addObserver: self
        //                                          selector: @selector(applicationWillResignActiveNotification)
        //                                              name: UIApplicationWillResignActiveNotification
        //                                            object: nil];
        
        // Track FPS using display link
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
        // [displayLink setPaused:YES];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [displayLink setPaused:NO];
    }
    return self;
}

- (void)displayLinkTick:(CADisplayLink *)link {
    CFTimeInterval currentTime = displayLink.timestamp;
	if (_lastTime == 0) {
		// first time.
		_lastTime = currentTime;
		return;
	}
	_tickCount++;
	CFTimeInterval delta = currentTime - _lastTime;
	if (delta < 1) return;
	// get fps
	self.fpsValue = MIN(lrint(_tickCount / delta), 120);
	_tickCount = 0;
	_lastTime = currentTime;
}

// - (void)applicationDidBecomeActiveNotification {
//     [displayLink setPaused:NO];
// }

// - (void)applicationWillResignActiveNotification {
//     [displayLink setPaused:YES];
// }

@end