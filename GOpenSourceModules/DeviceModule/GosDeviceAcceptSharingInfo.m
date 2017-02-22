//
//  GosDeviceAcceptSharingInfo.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2017/1/5.
//  Copyright © 2017年 Gizwits. All rights reserved.
//

#import "GosDeviceAcceptSharingInfo.h"
#import <GizWifiSDK/GizWifiSDK.h>
#import "GosCommon.h"

@interface GosDeviceAcceptSharingInfo () <GizDeviceSharingDelegate>

@property (weak, nonatomic) IBOutlet UILabel *textSharingInfo;
@property (weak, nonatomic) IBOutlet UILabel *textSharingTips;

@property (strong, nonatomic) NSString *userName;
@property (strong, nonatomic) NSString *deviceInfo;
@property (strong, nonatomic) NSString *qrcode;
@property (strong, nonatomic) NSDate *expiredDate;

@property (strong, nonatomic) NSTimer *timer;//倒计时计时器

@property (weak, nonatomic) IBOutlet UIButton *btnOK;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;

@end

@implementation GosDeviceAcceptSharingInfo

- (id)initWithUser:(NSString *)user deviceInfo:(NSString *)deviceInfo qrcode:(NSString *)qrcode expiredDate:(NSDate *)expiredDate {
    self = [super init];
    if (self) {
        self.userName = user;
        self.deviceInfo = deviceInfo;
        self.qrcode = qrcode;
        self.expiredDate = expiredDate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.title = NSLocalizedString(@"Scan QRCode to bind", nil);
    
    self.textSharingInfo.text = [NSString stringWithFormat:NSLocalizedString(@"qrcode_sharing_format", nil), self.userName, self.deviceInfo];
    [self onTimer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [GizDeviceSharing setDelegate:self];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)onTimer {
    if (self.expiredDate) {
        NSTimeInterval expired = [self.expiredDate timeIntervalSinceNow];
        if (expired <= 0) {
            [self.timer invalidate];
            self.timer = nil;
            self.textSharingTips.text = NSLocalizedString(@"Tips: The device sharing have been expired", nil);
            self.btnOK.enabled = NO;
            self.btnOK.backgroundColor = [UIColor lightGrayColor];
            self.btnCancel.enabled = NO;
            self.btnCancel.backgroundColor = [UIColor lightGrayColor];
            return;
        }
        float n;
        float p = modff(expired/60, &n);
        if (p > 0) {
            n = n + 1;
        }
        self.textSharingTips.text = [NSString stringWithFormat:NSLocalizedString(@"qrcode_sharing_tip_format", nil), @(n)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onConfirm:(id)sender {
    showHUDAddedTo(self.view, YES);
    [GizDeviceSharing acceptDeviceSharingByQRCode:[GosCommon sharedInstance].token QRCode:self.qrcode];
}

- (IBAction)onCancel:(id)sender {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)didAcceptDeviceSharingByQRCode:(NSError *)result {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onCancel:nil];
    } else {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Your request is failed", nil) disappear:YES];
    }
}

@end
