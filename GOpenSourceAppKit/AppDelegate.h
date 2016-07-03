//
//  AppDelegate.h
//  GBOSA
//
//  Created by Zono on 16/3/22.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import <UIKit/UIKit.h>

#warning - please replace your app info

#define APP_ID  @"please replace your app id"
#define APP_SECRET  @"please replace your app secret"

#define TENCENT_APP_ID @"please replace your tencent app id"

#define JPUSH_APP_KEY @"please replace your jpush app key"

#define BPUSH_API_KEY @"please replace your bpush api key"

// 只能选择支持其中一种
//#define __JPush       // 极光推送
//#define __BPush         // 百度推送

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;


@end

