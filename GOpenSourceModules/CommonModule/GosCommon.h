//
//  Common.h
//  GBOSA
//
//  Created by Zono on 16/4/11.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UIImageView+PlayGIF.h"
#import "MBProgressHUD.h"
#import "GizLog.h"
#import <GizWifiSDK/GizWifiDefinitions.h>
#import <GizWifiSDK/GizWifiSDK.h>
#import "WXApi.h"
#import "GizKeychainRecorder.h"

#define DEFAULT_SITE_DOMAIN     @"site.gizwits.com"

/**
 登录类型类型
 */
typedef NS_ENUM(NSInteger, GizLoginStatus) {
    
    /**
     未登录
     */
    GizLoginNone = 0,
    
    /**
     用户登录
     */
    GizLoginUser = 1,
};

//#import "GizDeviceListViewController.h"

@class GizWifiDevice;


typedef void (^GosRecordPageBlock)(UIViewController *viewController);
typedef void (^GosSettingPageBlock)(UIViewController *viewController);
typedef void (^GosControlBlock)(GizWifiDevice *device, UIViewController *viewController);
typedef void (^WXApiOnRespBlock)(BaseResp *resp);

@interface GosCommon : NSObject

+ (instancetype)sharedInstance;

- (id)init NS_UNAVAILABLE;

+ (BOOL)isMobileNumber:(NSString *)mobileNum;

- (void)tempSaveUser:(NSString *)username password:(NSString *)password clearUserDefaults:(BOOL)clearUserDefaults;
- (void)saveUserDefaults:(NSString *)username password:(NSString *)password uid:(NSString *)uid token:(NSString *)token;
- (void)removeUserDefaults;

@property (strong) NSString *ssid;

@property (assign) id delegate;

@property (strong, readonly) NSString *tmpUser;
@property (strong, readonly) NSString *tmpPass;
@property (strong) NSString *uid;
@property (strong) NSString *token;
@property (assign) GizLoginStatus currentLoginStatus;
@property (assign) BOOL isThirdAccount;
@property (strong) GosControlBlock controlHandler; //自定义控制页面
@property (strong) GosRecordPageBlock recordPageHandler; //自定义页面统计
@property (strong) GosSettingPageBlock settingPageHandler; //自定义设置页面
@property (strong) WXApiOnRespBlock WXApiOnRespHandler;

@property (strong) NSArray *sharingMessageList; //分享消息列表

@property (nonatomic, strong) NSArray *configModuleValueArray;
@property (nonatomic, strong) NSArray *configModuleTextArray;
@property (assign) GizWifiGAgentType airlinkConfigType;

@property (nonatomic, strong) UIAlertView *cancelAlertView;

@property (nonatomic, strong) NSString *cid;
/********************* 初始化参数 *********************/
@property (nonatomic, strong, readonly) NSString *appID;
@property (nonatomic, strong, readonly) NSString *appSecret;
@property (nonatomic, strong, readonly) NSArray *productKey;
@property (nonatomic, assign, readonly) BOOL moduleSelectOn;
@property (nonatomic, strong, readonly) NSString *tencentAppID;
@property (nonatomic, strong, readonly) NSString *wechatAppID;
@property (nonatomic, strong, readonly) NSString *wechatAppSecret;
@property (nonatomic, assign, readonly) NSInteger pushType;
@property (nonatomic, strong, readonly) NSString *jpushAppKey;
@property (nonatomic, strong, readonly) NSString *bpushAppKey;
@property (nonatomic, assign, readonly) BOOL qqOn;
@property (nonatomic, assign, readonly) BOOL wechatOn;
@property (nonatomic, assign, readonly) BOOL anonymousLoginOn;
@property (nonatomic, assign, readonly) BOOL devlistTabOn;

@property (nonatomic, strong, readonly) NSMutableDictionary *cloudDomainDict;

/******************** 定制界面样式 ********************/
@property (nonatomic, strong, readonly) UIColor *buttonColor;
@property (nonatomic, strong, readonly) UIColor *buttonTextColor;
@property (nonatomic, strong, readonly) UIColor *configProgressViewColor;
@property (nonatomic, strong, readonly) UIColor *navigationBarColor;
@property (nonatomic, strong, readonly) UIColor *navigationBarTextColor;
@property (nonatomic, assign, readonly) UIStatusBarStyle statusBarStyle;
@property (nonatomic, strong, readonly) NSString *addDeviceTitle;

//[UIColor purpleColor]
//#define BUTTON_COLOR [UIColor colorWithRed:0.973 green:0.855 blue:0.247 alpha:1]
#define BUTTON_TEXT_COLOR [UIColor colorWithRed:0.322 green:0.244 blue:0.747 alpha:1]

//@property (assign) BOOL isLogin;
//@property (assign) BOOL hasBeenLoggedIn;

//@property (strong) GizDeviceListViewController *deviceList;

/*
 * ssid 缓存
 */
- (void)saveSSID:(NSString *)ssid key:(NSString *)key;
- (NSString *)getPasswrodFromSSID:(NSString *)ssid;

/**
 * appID、appSecret、域名、端口
 * @note {"APPID": xxx, "APPSECRET": xxx, "site": {"domain": xxx, "port": xxx}, "api": {"domain": xxx, "port": xxx}}
 */
- (BOOL)setApplicationInfo:(NSDictionary *)info;
- (NSDictionary *)getApplicationInfo;
- (NSString *)getAppSecret;

/*
 * 判断错误码
 */
- (NSString *)checkErrorCode:(GizWifiErrorCode)errorCode;

/*
 * UIAlertView
 */
- (void)showAlert:(NSString *)message disappear:(BOOL)disappear;

/*
 * 回到主页
 */
- (void)onCancel;
- (void)onSucceed:(GizWifiDevice *)device;
- (void)showAlertCancelConfig:(id)delegate;
- (void)cancelAlertViewDismiss;

/**
 格式：xxxx-xx-xxTxx:xx:xxZ
 */
+ (NSDate *)serviceDateFromString:(NSString *)dateStr;
+ (NSString *)localDateStringFromDate:(NSDate *)date;

@end

#define SSID_PREFIX     @"XPG-GAgent"
#import <SystemConfiguration/CaptiveNetwork.h>

static inline NSString *GetCurrentSSID() {
    NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    for (NSString *interface in interfaces) {
        NSDictionary *ssidInfo = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interface);
        NSString *ssid = ssidInfo[(__bridge_transfer NSString *)kCNNetworkInfoKeySSID];
        if (ssid.length > 0) {
            return ssid;
        }
    }
    return @"";
}

id GetControllerWithClass(Class class, UITableView *tableView, NSString *reuseIndentifer);

#define ALERT_TAG_CANCEL_CONFIG     1001
#define ALERT_TAG_EMPTY_PASSWORD    1002

static inline void SHOW_ALERT_CANCEL_CONFIG(id delegate) {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"tip", nil) message:NSLocalizedString(@"Discard your configuration?", nil) delegate:delegate cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    alertView.tag = ALERT_TAG_CANCEL_CONFIG;
    [alertView show];
}

static inline void SHOW_ALERT_EMPTY_PASSWORD(id delegate) {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"tip", nil) message:NSLocalizedString(@"Password is empty?", nil) delegate:delegate cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
    alertView.tag = ALERT_TAG_EMPTY_PASSWORD;
    [alertView show];
}

#define CUSTOM_YELLOW_COLOR() \
[UIColor colorWithRed:249/255.0 green:220/255.0 blue:39/255.0 alpha:1]

#import <sys/sysctl.h>

#ifndef XcodeAppBundle
#define XcodeAppBundle  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]
#endif

#ifndef XcodeAppVersion
#define XcodeAppVersion [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]
#endif

static inline NSString *getPhoneId() {
    NSString *phoneId = [GizKeychainRecorder load:XcodeAppBundle];
    if (phoneId.length == 0) {
        phoneId = [[UIDevice currentDevice].identifierForVendor UUIDString];
        [GizKeychainRecorder save:XcodeAppBundle data:phoneId];
    }
    return phoneId;
}

static inline NSString *getCurrentDeviceModel() {
    int mib[2];
    size_t len;
    char *machine;
    
    mib[0] = CTL_HW;
    mib[1] = HW_MACHINE;
    sysctl(mib, 2, NULL, &len, NULL, 0);
    machine = malloc(len);
    sysctl(mib, 2, machine, &len, NULL, 0);
    
    NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
    free(machine);
    
    NSDictionary *models = @{@"iPhone4,1": @"iPhone 4S",
                             @"iPhone5,1": @"iPhone 5 (GSM/LTE)",
                             @"iPhone5,2": @"iPhone 5 (CDMA/LTE)",
                             @"iPhone5,3": @"iPhone 5c (GSM/LTE)",
                             @"iPhone5,4": @"iPhone 5c (CDMA/LTE)",
                             @"iPhone6,1": @"iPhone 5s (GSM/LTE)",
                             @"iPhone6,2": @"iPhone 5s (CDMA/LTE)",
                             @"iPhone7,1": @"iPhone 6 Plus",
                             @"iPhone7,2": @"iPhone 6",
                             @"iPhone8,1": @"iPhone 6s",
                             @"iPhone8,2": @"iPhone 6s Plus",
                             @"iPhone8,4": @"iPhone SE",
                             @"iPhone9,1": @"iPhone 7 (CDMA+GSM/LTE)",
                             @"iPhone9,2": @"iPhone 7 Plus (CDMA+GSM/LTE)",
                             @"iPhone9,3": @"iPhone 7 (GSM/LTE)",
                             @"iPhone9,4": @"iPhone 7 Plus (GSM/LTE)",

                             @"iPod5,1": @"iPod Touch 5",
                             @"iPod7,1": @"iPod touch 6",
                             
                             @"iPad2,1": @"iPad 2 (Wi‑Fi)",
                             @"iPad2,2": @"iPad 2 (GSM)",
                             @"iPad2,3": @"iPad 2 (CDMA)",
                             @"iPad2,4": @"iPad 2 (Wi‑Fi, A5R)",
                             @"iPad2,5": @"iPad mini (Wi‑Fi)",
                             @"iPad2,6": @"iPad mini (GSM/LTE)",
                             @"iPad2,7": @"iPad mini (CDMA/LTE)",
                             
                             @"iPad3,1": @"iPad 3 (Wi‑Fi)",
                             @"iPad3,2": @"iPad 3 (GSM/LTE)",
                             @"iPad3,3": @"iPad 3 (CDMA/LTE)",
                             @"iPad3,4": @"iPad 4 (Wi‑Fi)",
                             @"iPad3,5": @"iPad 4 (GSM/LTE)",
                             @"iPad3,6": @"iPad 4 (CDMA/LTE)",
                             
                             @"iPad4,1": @"iPad Air (Wi‑Fi)",
                             @"iPad4,2": @"iPad Air (LTE)",
                             @"iPad4,3": @"iPad Air (China)",
                             @"iPad4,4": @"iPad Mini 2 (Wi‑Fi)",
                             @"iPad4,5": @"iPad Mini 2 (LTE)",
                             @"iPad4,6": @"iPad Mini 2 (China)",
                             @"iPad4,7": @"iPad Mini 3 (Wi‑Fi)",
                             @"iPad4,8": @"iPad Mini 3 (LTE)",
                             @"iPad4,9": @"iPad Mini 3 (China)",
                             
                             @"iPad5,1": @"iPad mini 4 (Wi-Fi)",
                             @"iPad5,2": @"iPad mini 4 (LTE)",
                             @"iPad5,3": @"iPad Air 2 (Wi‑Fi)",
                             @"iPad5,4": @"iPad Air 2 (LTE)",

                             @"iPad6,3": @"iPad Pro (9.7 inch) (Wi-Fi)",
                             @"iPad6,4": @"iPad Pro (9.7 inch) (LTE)",
                             @"iPad6,7": @"iPad Pro (12.9 inch) (Wi-Fi)",
                             @"iPad6,8": @"iPad Pro (12.9 inch) (LTE)",
                             };
    
    NSString *newPlatform = models[platform];
    if (newPlatform.length > 0) {
        return newPlatform;
    }
    
    if ([platform isEqualToString:@"i386"] ||
        [platform isEqualToString:@"x86_64"])    return @"iPhone Simulator";
    return platform;
}

static inline bool AppLogInit(int logLevel) {
    NSURL *documentsDictoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    [[NSFileManager defaultManager] createDirectoryAtPath:documentsDictoryURL.path withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSDictionary *sysInfo = @{@"phone_id": getPhoneId(),
                              @"os": @"iOS",
                              @"os_ver": [[UIDevice currentDevice] systemVersion],
                              @"app_version": XcodeAppVersion,
                              @"phone_model": getCurrentDeviceModel()};
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sysInfo options:0 error:nil];
    NSString *strSysInfo = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    int ret = GizLogInit(strSysInfo.UTF8String, [documentsDictoryURL.path stringByAppendingString:@"/"].UTF8String, logLevel);
    if (0 != ret) {
        GIZ_LOG_ERROR("failed, errorCode: %i", ret);
    }
    return (ret == 0);
}

static inline void showHUDAddedTo(UIView *view, BOOL animated) {
    NSCAssert(view, @"view could not be nil");
    MBProgressHUD *hud = [MBProgressHUD HUDForView:view];
    if (!animated || hud.alpha == 0) {
        [MBProgressHUD showHUDAddedTo:view animated:animated];
    }
}
