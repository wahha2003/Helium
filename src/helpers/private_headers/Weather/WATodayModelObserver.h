@class WATodayModel, WAForecastModel;

@protocol WATodayModelObserver <NSObject>
@required
-(void)todayModelWantsUpdate:(WATodayModel *)model;
-(void)todayModel:(WATodayModel *)model forecastWasUpdated:(WAForecastModel *)forecast;

@end