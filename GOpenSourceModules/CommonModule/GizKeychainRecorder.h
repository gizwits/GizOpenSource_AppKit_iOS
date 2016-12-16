//
//  GizKeychainRecorder.h
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/14.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GizKeychainRecorder : NSObject

+ (void)save:(NSString *)service data:(id)data;
+ (id)load:(NSString *)service;
+ (void)delete:(NSString *)service;

@end
