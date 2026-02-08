@class HWeatherController;

@protocol HWeatherControllerObserver <NSObject>
@required
-(void)weatherModelUpdatedForController:(HWeatherController *)weatherController;
@end