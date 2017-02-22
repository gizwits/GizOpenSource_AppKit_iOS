//
//  GosSharingManagerViewController.h
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GizWifiSDK/GizWifiSDK.h>

@interface GosSharingManagerViewController : UIViewController

@property (strong, nonatomic) GizWifiDevice *device;

+ (NSString *)userNameFromUserInfo:(GizUserInfo *)userInfo;

@end
