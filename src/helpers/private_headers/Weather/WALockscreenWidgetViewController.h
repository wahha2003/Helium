@class WATodayModel;

@interface WALockscreenWidgetViewController : UIViewController
@property (nonatomic, strong) WATodayModel *todayModel;
+ (WALockscreenWidgetViewController *)sharedInstanceIfExists;
- (id)_temperature;
- (id)_locationName;
- (void)updateWeather;
- (void)_updateTodayView;
- (void)_updateWithReason:(id)reason;
- (void)_setupWeatherModel;
- (void)todayModelWantsUpdate:(WATodayModel *)todayModel;

@end