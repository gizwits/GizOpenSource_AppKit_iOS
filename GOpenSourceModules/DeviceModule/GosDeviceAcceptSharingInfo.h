//
//  GosDeviceAcceptSharingInfo.h
//  GOpenSource_AppKit
//
//  Created by Tom on 2017/1/5.
//  Copyright © 2017年 Gizwits. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GosDeviceAcceptSharingInfo : UIViewController

- (id)initWithUser:(NSString *)user deviceInfo:(NSString *)deviceInfo qrcode:(NSString *)qrcode expiredDate:(NSDate *)expiredDate;

@end
