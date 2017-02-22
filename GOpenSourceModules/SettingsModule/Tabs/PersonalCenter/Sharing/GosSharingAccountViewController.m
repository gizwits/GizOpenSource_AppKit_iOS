//
//  GosSharingAccountViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/22.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosSharingAccountViewController.h"
#import <GizWifiSDK/GizWifiSDK.h>
#import "GosSharingManagerViewController.h"
#import "GosCommon.h"

@interface GosSharingAccountViewController () <UIActionSheetDelegate, GizDeviceSharingDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labelDescription;
@property (weak, nonatomic) IBOutlet UILabel *labelAccountInfo;
@property (weak, nonatomic) IBOutlet UITextField *textUserName;

@property (strong, nonatomic) GizWifiDevice *device;

@end

@implementation GosSharingAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    GizWifiDevice *device = nil;
    for (UIViewController *controller in self.navigationController.viewControllers) {
        if ([controller isMemberOfClass:[GosSharingManagerViewController class]]) {
            device = ((GosSharingManagerViewController *)controller).device;
        }
    }
    self.device = device;
    NSString *desc = device.alias;
    if (desc.length == 0) {
        desc = device.productName;
    }
    if (desc.length == 0) {
        desc = NSLocalizedString(@"Device", nil);
    }
    self.labelDescription.text = [NSString stringWithFormat:NSLocalizedString(@"sharing_device_info_format", nil), desc];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [GizDeviceSharing setDelegate:self];
}

- (void)onCheckDetail:(GizUserAccountType)accountType {
    showHUDAddedTo(self.view, YES);
    [GizDeviceSharing sharingDevice:[GosCommon sharedInstance].token deviceID:self.device.did sharingWay:GizDeviceSharingByNormal guestUser:self.textUserName.text guestUserType:accountType];
}

- (IBAction)onConfirm:(id)sender {
    if (self.textUserName.text.length == 0) {
        NSString *tip = NSLocalizedString(@"tip", nil);
        NSString *ok = NSLocalizedString(@"OK", nil);
        NSString *msg = NSLocalizedString(@"User account can not be empty", nil);
        [[[UIAlertView alloc] initWithTitle:tip message:msg delegate:nil cancelButtonTitle:ok otherButtonTitles:nil] show];
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Normal User", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self onCheckDetail:GizUserNormal];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Phone User", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self onCheckDetail:GizUserPhone];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Email User", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self onCheckDetail:GizUserEmail];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Other User", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self onCheckDetail:GizUserOther];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)didSharingDevice:(NSError *)result deviceID:(NSString *)deviceID sharingID:(NSInteger)sharingID QRCodeImage:(UIImage *)QRCodeImage {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Send successfully", nil) disappear:YES];
    } else {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Send failed", nil) disappear:YES];
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

@end
