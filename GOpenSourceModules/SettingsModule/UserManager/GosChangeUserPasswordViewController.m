//
//  GosChangeUserPasswordViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom Ge on 2016/11/18.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosChangeUserPasswordViewController.h"

#import "GosCommon.h"

#import "GosUserChangeTableViewCell.h"
#import "GosUserPasswordTableViewCell.h"

@interface GosChangeUserPasswordViewController () <GizWifiSDKDelegate>

@property (weak, nonatomic) UITextField *textOrigin;
@property (weak, nonatomic) UITextField *textNew;
@property (weak, nonatomic) UITextField *textRepeat;

@end

@implementation GosChangeUserPasswordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [GizWifiSDK sharedInstance].delegate = self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 3;
            
        default:
            break;
    }
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 56;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Configure the cell...
    if (indexPath.section == 0) {
        GosUserPasswordTableViewCell *passwordCell = GetControllerWithClass([GosUserPasswordTableViewCell class], tableView, @"GosUserPasswordTableViewCell");
        switch (indexPath.row) {
            case 0:
                self.textOrigin = passwordCell.textPassword;
                self.textOrigin.placeholder = NSLocalizedString(@"Enter current password", @"请输入原密码");
                break;
            case 1:
                self.textNew = passwordCell.textPassword;
                self.textNew.placeholder = NSLocalizedString(@"Enter new password", @"请设置新密码");
                break;
            case 2:
                self.textRepeat = passwordCell.textPassword;
                self.textRepeat.placeholder = NSLocalizedString(@"Re-enter new password", @"请再次确认密码");
                break;
                
            default:
                break;
        }
        return passwordCell;
    } else {
        return GetControllerWithClass([GosUserChangeTableViewCell class], tableView, @"GosUserChangeTableViewCell");
    }
    
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    //确认修改密码
    if (self.textOrigin.text.length == 0) {
        NSString *strTip = NSLocalizedString(@"tip", @"提示");
        NSString *strMessage = NSLocalizedString(@"Enter current password", @"请输入原密码");
        NSString *strConfirm = NSLocalizedString(@"OK", @"确定");
        [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        return;
    }
    
    if (self.textNew.text.length == 0) {
        NSString *strTip = NSLocalizedString(@"tip", @"提示");
        NSString *strMessage = NSLocalizedString(@"Enter new password", @"请设置新密码");
        NSString *strConfirm = NSLocalizedString(@"OK", @"确定");
        [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        return;
    }
    
    if (self.textRepeat.text.length == 0) {
        NSString *strTip = NSLocalizedString(@"tip", @"提示");
        NSString *strMessage = NSLocalizedString(@"Re-enter new password", @"请再次确认密码");
        NSString *strConfirm = NSLocalizedString(@"OK", @"确定");
        [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        return;
    }
    
    if (![self.textNew.text isEqualToString:self.textRepeat.text]) {
        NSString *strTip = NSLocalizedString(@"tip", @"提示");
        NSString *strConfirm = NSLocalizedString(@"OK", @"确定");
        NSString *strMessage = NSLocalizedString(@"Password does not match the confirm password", @"新密码和确认密码不相同");
        [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        return;
    }
    
    NSString *token = [GosCommon sharedInstance].token;
    [[GizWifiSDK sharedInstance] changeUserPassword:token oldPassword:self.textOrigin.text newPassword:self.textNew.text];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)wifiSDK:(GizWifiSDK *)wifiSDK didChangeUserPassword:(NSError *)result {
    __block NSString *strTip = NSLocalizedString(@"tip", @"提示");
    __block NSString *strConfirm = NSLocalizedString(@"OK", @"确定");
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        GosCommon *common = [GosCommon sharedInstance];
        [common saveUserDefaults:common.tmpUser password:self.textNew.text uid:nil token:nil];
        NSString *strMessage = NSLocalizedString(@"Password change successful", @"密码修改成功");
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:strTip message:strMessage preferredStyle:UIAlertControllerStyleAlert];
        __weak __typeof(self) weakSelf = self;
        
        [alertController addAction:[UIAlertAction actionWithTitle:strConfirm style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            __strong __typeof(self) strongSelf = weakSelf;
            if (strongSelf.navigationController.viewControllers.lastObject == strongSelf) {
                [strongSelf.navigationController popViewControllerAnimated:YES];
            }
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        if (result.code == GIZ_OPENAPI_USERNAME_PASSWORD_ERROR) {
            NSString *strMessage = NSLocalizedString(@"Current password invalid", @"原密码输入有误");
            [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        } else {
            NSString *strMessage = NSLocalizedString(@"Password change failed", @"密码修改失败");
            [[[UIAlertView alloc] initWithTitle:strTip message:strMessage delegate:nil cancelButtonTitle:strConfirm otherButtonTitles:nil] show];
        }
    }
}

@end
