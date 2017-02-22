//
//  DeviceListViewController.h
//  GBOSA
//
//  Created by Zono on 16/5/6.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GosConfigStart.h"

@interface GosDeviceListViewController : UIViewController <GosConfigStartDelegate>

@property (nonatomic, strong) UIViewController *parent;
@property (nonatomic, strong) NSArray *deviceListArray;

@end
