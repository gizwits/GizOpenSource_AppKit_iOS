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
typedef void (^GosSettingPageBlock)(UINavigationController *viewController);
typedef void (^GosControlBlock)(GizWifiDevice *device, UIViewController *deviceListController);
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
    
    if ([platform isEqualToString:@"iPhone1,1"]) return @"iPhone 2G (A1203)";
    if ([platform isEqualToString:@"iPhone1,2"]) return @"iPhone 3G (A1241/A1324)";
    if ([platform isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS (A1303/A1325)";
    if ([platform isEqualToString:@"iPhone3,1"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,2"]) return @"iPhone 4 (A1332)";
    if ([platform isEqualToString:@"iPhone3,3"]) return @"iPhone 4 (A1349)";
    if ([platform isEqualToString:@"iPhone4,1"]) return @"iPhone 4S (A1387/A1431)";
    if ([platform isEqualToString:@"iPhone5,1"]) return @"iPhone 5 (A1428)";
    if ([platform isEqualToString:@"iPhone5,2"]) return @"iPhone 5 (A1429/A1442)";
    if ([platform isEqualToString:@"iPhone5,3"]) return @"iPhone 5c (A1456/A1532)";
    if ([platform isEqualToString:@"iPhone5,4"]) return @"iPhone 5c (A1507/A1516/A1526/A1529)";
    if ([platform isEqualToString:@"iPhone6,1"]) return @"iPhone 5s (A1453/A1533)";
    if ([platform isEqualToString:@"iPhone6,2"]) return @"iPhone 5s (A1457/A1518/A1528/A1530)";
    if ([platform isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus (A1522/A1524)";
    if ([platform isEqualToString:@"iPhone7,2"]) return @"iPhone 6 (A1549/A1586)";
    
    if ([platform isEqualToString:@"iPod1,1"])   return @"iPod Touch 1G (A1213)";
    if ([platform isEqualToString:@"iPod2,1"])   return @"iPod Touch 2G (A1288)";
    if ([platform isEqualToString:@"iPod3,1"])   return @"iPod Touch 3G (A1318)";
    if ([platform isEqualToString:@"iPod4,1"])   return @"iPod Touch 4G (A1367)";
    if ([platform isEqualToString:@"iPod5,1"])   return @"iPod Touch 5G (A1421/A1509)";
    
    if ([platform isEqualToString:@"iPad1,1"])   return @"iPad 1G (A1219/A1337)";
    
    if ([platform isEqualToString:@"iPad2,1"])   return @"iPad 2 (A1395)";
    if ([platform isEqualToString:@"iPad2,2"])   return @"iPad 2 (A1396)";
    if ([platform isEqualToString:@"iPad2,3"])   return @"iPad 2 (A1397)";
    if ([platform isEqualToString:@"iPad2,4"])   return @"iPad 2 (A1395+New Chip)";
    if ([platform isEqualToString:@"iPad2,5"])   return @"iPad Mini 1G (A1432)";
    if ([platform isEqualToString:@"iPad2,6"])   return @"iPad Mini 1G (A1454)";
    if ([platform isEqualToString:@"iPad2,7"])   return @"iPad Mini 1G (A1455)";
    
    if ([platform isEqualToString:@"iPad3,1"])   return @"iPad 3 (A1416)";
    if ([platform isEqualToString:@"iPad3,2"])   return @"iPad 3 (A1403)";
    if ([platform isEqualToString:@"iPad3,3"])   return @"iPad 3 (A1430)";
    if ([platform isEqualToString:@"iPad3,4"])   return @"iPad 4 (A1458)";
    if ([platform isEqualToString:@"iPad3,5"])   return @"iPad 4 (A1459)";
    if ([platform isEqualToString:@"iPad3,6"])   return @"iPad 4 (A1460)";
    
    if ([platform isEqualToString:@"iPad4,1"])   return @"iPad Air (A1474)";
    if ([platform isEqualToString:@"iPad4,2"])   return @"iPad Air (A1475)";
    if ([platform isEqualToString:@"iPad4,3"])   return @"iPad Air (A1476)";
    if ([platform isEqualToString:@"iPad4,4"])   return @"iPad Mini 2G (A1489)";
    if ([platform isEqualToString:@"iPad4,5"])   return @"iPad Mini 2G (A1490)";
    if ([platform isEqualToString:@"iPad4,6"])   return @"iPad Mini 2G (A1491)";
    
    if ([platform isEqualToString:@"i386"])      return @"iPhone Simulator";
    if ([platform isEqualToString:@"x86_64"])    return @"iPhone Simulator";
    return platform;
}

static inline bool AppLogInit() {
    int logLevel = 2;
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
