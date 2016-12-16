//
//  GizSchedulerInfo.h
//  GizWifiSDK
//
//  Created by GeHaitong on 16/8/9.
//  Copyright © 2016年 gizwits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GizWifiSDK/GizWifiDefinitions.h>

@interface GizSchedulerInfo : NSObject

- (GizSchedulerInfo *)init;

@property (strong, nonatomic, readonly) NSString *sid;
@property (strong, nonatomic, readonly) NSString *createdDateTime;

@property (strong, nonatomic) NSString *date;
@property (strong, nonatomic) NSString *time;
@property (strong, nonatomic) NSString *remark;
@property (strong, nonatomic) NSArray *weekdays;
@property (strong, nonatomic) NSArray *monthDays;
@property (strong, nonatomic) NSString *startDate;
@property (strong, nonatomic) NSString *endDate;
@property (assign, nonatomic) BOOL enabled;
@property (strong, nonatomic) NSDictionary *attrs;

@property (strong, nonatomic) NSArray *taskList DEPRECATED_ATTRIBUTE;
@property (assign, nonatomic) GizScheduleRepeatRule repeatRule DEPRECATED_ATTRIBUTE;
@property (assign, nonatomic) NSInteger repeatCount DEPRECATED_ATTRIBUTE;

@end
