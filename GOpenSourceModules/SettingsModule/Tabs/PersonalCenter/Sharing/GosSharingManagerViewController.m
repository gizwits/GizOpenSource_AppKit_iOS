//
//  GosSharingManagerViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosSharingManagerViewController.h"
#import <GizWifiSDK/GizWifiSDK.h>
#import "GosCommon.h"

@interface GosSharingManagerViewController () <UITableViewDelegate, UITableViewDataSource, GizDeviceSharingDelegate>

@property (weak, nonatomic) IBOutlet UIButton *btnSharingStatus;
@property (weak, nonatomic) IBOutlet UIButton *btnBindUsers;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSArray *list;

@property (assign, nonatomic) BOOL isEditing;//编辑模式

//切换选项卡的样式
@property (weak, nonatomic) IBOutlet UITableView *tableView2;//这个列表是全屏的，底下没有添加按钮的
@property (strong, nonatomic) UIBarButtonItem *backupItem;

@end

@implementation GosSharingManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [GizDeviceSharing setDelegate:self];
    [self onSharingStatus:nil];
}

- (IBAction)onSharingStatus:(id)sender {
    self.btnSharingStatus.selected = YES;
    self.btnBindUsers.selected = NO;
    self.tableView.hidden = NO;
    self.tableView2.hidden = YES;
    
    [self onUpdateSharingList];
}

- (void)onUpdateSharingList {
    if (nil != self.backupItem) { //只有共享状态支持导航按钮
        self.navigationItem.rightBarButtonItem = self.backupItem;
    }
    
    if (self.device.sharingRole == GizDeviceSharingOwner) { //只有owner支持调接口
        showHUDAddedTo(self.view, YES);
        [GizDeviceSharing getDeviceSharingInfos:[GosCommon sharedInstance].token sharingType:GizDeviceSharingByMe deviceID:self.device.did];
    } else {
        self.list = nil;
        [self autoReloadTableView];
    }
}

- (IBAction)onBindUsers:(id)sender {
    self.btnSharingStatus.selected = NO;
    self.btnBindUsers.selected = YES;
    self.backupItem = self.navigationItem.rightBarButtonItem;
    self.navigationItem.rightBarButtonItem = nil;
    self.tableView.hidden = YES;
    self.tableView2.hidden = NO;
    
    if (self.device.sharingRole == GizDeviceSharingOwner) { //只有owner支持调接口
        showHUDAddedTo(self.view, YES);
        [GizDeviceSharing getBindingUsers:[GosCommon sharedInstance].token deviceID:self.device.did];
    } else {
        self.list = nil;
        [self autoReloadTableView];
    }
}

- (IBAction)onEdit:(UIBarButtonItem *)sender {
    self.isEditing = !self.isEditing;
    if (self.isEditing) {
        self.tableView.hidden = YES;
        self.tableView2.hidden = NO;
        self.btnBindUsers.enabled = NO;
        [self autoReloadTableView];
        sender.title = NSLocalizedString(@"Cancel", nil);
    } else {
        self.tableView.hidden = NO;
        self.tableView2.hidden = YES;
        self.btnBindUsers.enabled = YES;
        [self autoReloadTableView];
        sender.title = NSLocalizedString(@"Edit", nil);
    }
}

- (void)autoReloadTableView {
    if (self.tableView2.hidden == NO) {
        [self.tableView2 reloadData];
    } else if (self.tableView.hidden == NO) {
        [self.tableView reloadData];
    }
}

+ (NSString *)userNameFromUserInfo:(GizUserInfo *)userInfo {
    NSString *userName = userInfo.username;
    if (userName.length == 0) {
        userName = userInfo.phone;
    }
    if (userName.length == 0) {
        userName = userInfo.email;
    }
    if (userName.length == 0) {
        if (userInfo.uid.length == 32) { //处理用户信息
            NSString *uidfirst = [userInfo.uid substringToIndex:3];
            NSString *uidlast = [userInfo.uid substringFromIndex:userInfo.uid.length-3];
            userName = [NSString stringWithFormat:@"%@****%@", uidfirst, uidlast];
        }
    }
    return userName;
}

- (BOOL)isSharingInfoTimeout:(GizDeviceSharingInfo *)sharingInfo {
    if (![sharingInfo isKindOfClass:[GizDeviceSharingInfo class]]) {
        return NO;
    }
    NSDate *expiredDate = [GosCommon serviceDateFromString:sharingInfo.expiredAt];
    NSTimeInterval timerInterval = [expiredDate timeIntervalSinceNow];
    return (timerInterval <= 0);
}

- (void)showCancelSharingAlert:(GizUserInfo *)userInfo handler:(void (^ __nullable)())handler {
    NSString *tip = NSLocalizedString(@"tip", nil);
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"cancel_sharing_format", nil), [GosSharingManagerViewController userNameFromUserInfo:userInfo]];
    NSString *ok = NSLocalizedString(@"OK", nil);
    NSString *cancel = NSLocalizedString(@"Cancel", nil);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:tip message:message preferredStyle:UIAlertControllerStyleAlert];
    
    __weak __typeof(self)weakSelf = self;
    [alertController addAction:[UIAlertAction actionWithTitle:cancel style:UIAlertActionStyleCancel handler:nil]];
    [alertController addAction:[UIAlertAction actionWithTitle:ok style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        showHUDAddedTo(strongSelf.view, YES);
        if (handler) {
            handler();
        }
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.list.count == 0) {
        return 1;
    }
    return self.list.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"sharingIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.imageView.image = nil;
    
    if (self.list.count > indexPath.row) {
        id obj = self.list[self.list.count-indexPath.row-1];
        if ([obj isKindOfClass:[GizDeviceSharingInfo class]]) {
            GizDeviceSharingInfo *sharingInfo = (GizDeviceSharingInfo *)obj;
            
            cell.imageView.image = [UIImage imageNamed:@"friends.png"];
            if (sharingInfo.alias.length > 0) { //优先显示别名
                cell.textLabel.text = sharingInfo.alias;
            } else {
                cell.textLabel.text = [GosSharingManagerViewController userNameFromUserInfo:sharingInfo.userInfo];
            }
            
            NSDate *currentDate = [GosCommon serviceDateFromString:sharingInfo.updatedAt];
            cell.detailTextLabel.text = [GosCommon localDateStringFromDate:currentDate];
            
            UILabel *labelStatus = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
            labelStatus.textAlignment = NSTextAlignmentRight;
            switch (sharingInfo.status) {
                case GizDeviceSharingNotAccepted:
                    if ([self isSharingInfoTimeout:sharingInfo]) { //超时
                        labelStatus.text = NSLocalizedString(@"Timeout", nil);
                    } else {
                        labelStatus.text = NSLocalizedString(@"Waiting for accept", nil);
                    }
                    break;
                case GizDeviceSharingAccepted:
                    labelStatus.text = NSLocalizedString(@"Accepted", nil);
                    break;
                case GizDeviceSharingRefused:
                    labelStatus.text = NSLocalizedString(@"Refused", nil);
                    break;
                case GizDeviceSharingCancelled:
                    labelStatus.text = NSLocalizedString(@"Cancelled", nil);
                    break;
                default:
                    labelStatus.text = @"";
                    break;
            }
            cell.accessoryView = labelStatus;
        } else if ([obj isKindOfClass:[GizUserInfo class]]) {
            GizUserInfo *userInfo = (GizUserInfo *)obj;
            cell.imageView.image = [UIImage imageNamed:@"friends.png"];
            cell.textLabel.text = [GosSharingManagerViewController userNameFromUserInfo:userInfo];
            NSDate *date = [GosCommon serviceDateFromString:userInfo.deviceBindTime];
            cell.detailTextLabel.text = [GosCommon localDateStringFromDate:date];
        }
    } else {
        if (self.btnSharingStatus.selected) {
            cell.textLabel.text = NSLocalizedString(@"have not been shared", nil);
        } else {
            cell.textLabel.text = NSLocalizedString(@"have no bound users", nil);
        }
    }
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *desc = self.device.alias;
    if (desc.length == 0) {
        desc = self.device.productName;
    }
    if (desc.length == 0) {
        desc = NSLocalizedString(@"Device", nil);
    }
    
    if (self.btnSharingStatus.selected) {
        return [NSString stringWithFormat:NSLocalizedString(@"sharing_to_format", nil), desc];
    }
    return [NSString stringWithFormat:NSLocalizedString(@"sharing_bind_users_format", nil), desc];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    __block id obj = self.list[self.list.count-indexPath.row-1];
    __block BOOL isSharingInfo = [obj isKindOfClass:[GizDeviceSharingInfo class]];
    __block BOOL isUserInfo = [obj isKindOfClass:[GizUserInfo class]];

    if (isSharingInfo) { //解绑用户
        __block GizDeviceSharingInfo *sharingInfo = (GizDeviceSharingInfo *)obj;
        if ((sharingInfo.status == GizDeviceSharingNotAccepted && [self isSharingInfoTimeout:obj]) ||
            sharingInfo.status == GizDeviceSharingRefused) { //重新分享，删除
            __weak __typeof(self)weakSelf = self;
            UITableViewRowAction *cancelButton = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"Delete", nil) handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self showCancelSharingAlert:sharingInfo.userInfo handler:^{
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    showHUDAddedTo(strongSelf.view, YES);
                    [GizDeviceSharing revokeDeviceSharing:[GosCommon sharedInstance].token sharingID:sharingInfo.id];
                }];
            }];
            UITableViewRowAction *reshareButton = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"Re-sharing", nil) handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                showHUDAddedTo(strongSelf.view, YES);
                [GizDeviceSharing sharingDevice:[GosCommon sharedInstance].token deviceID:strongSelf.device.did sharingWay:GizDeviceSharingByNormal guestUser:sharingInfo.userInfo.uid guestUserType:GizUserOther];
            }];
            reshareButton.backgroundColor = [UIColor grayColor];
            return @[cancelButton, reshareButton];
        } else if (sharingInfo.status == GizDeviceSharingCancelled) { //重新分享
            __weak __typeof(self)weakSelf = self;
            UITableViewRowAction *reshareButton = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"Re-sharing", nil) handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                showHUDAddedTo(strongSelf.view, YES);
                [GizDeviceSharing sharingDevice:[GosCommon sharedInstance].token deviceID:strongSelf.device.did sharingWay:GizDeviceSharingByNormal guestUser:sharingInfo.userInfo.uid guestUserType:GizUserOther];
            }];
            return @[reshareButton];
        } else { //取消分享
            __weak __typeof(self)weakSelf = self;
            return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"Cancel Sharing", nil) handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
                [self showCancelSharingAlert:sharingInfo.userInfo handler:^{
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    showHUDAddedTo(strongSelf.view, YES);
                    [GizDeviceSharing revokeDeviceSharing:[GosCommon sharedInstance].token sharingID:sharingInfo.id];
                }];
            }]];
        }
    } else if (isUserInfo) { //解绑用户
        __block GizUserInfo *userInfo = (GizUserInfo *)obj;
        __weak __typeof(self)weakSelf = self;
        return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:NSLocalizedString(@"Cancel Sharing", nil) handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
            [self showCancelSharingAlert:userInfo handler:^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                showHUDAddedTo(strongSelf.view, YES);
                [GizDeviceSharing unbindUser:[GosCommon sharedInstance].token deviceID:strongSelf.device.did guestUID:userInfo.uid];
            }];
        }]];
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath { //ios8 only
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.list.count > indexPath.row) {
        id obj = self.list[self.list.count-indexPath.row-1];
        if ([obj isKindOfClass:[GizDeviceSharingInfo class]]) {
            return YES;
        } else if ([obj isKindOfClass:[GizUserInfo class]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.list.count > indexPath.row) {
        return self.isEditing;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    id obj = self.list[self.list.count-indexPath.row-1];
    if ([obj isKindOfClass:[GizDeviceSharingInfo class]]) { //只有共享状态列表，才能编辑别名
        __block GizDeviceSharingInfo *sharingInfo = (GizDeviceSharingInfo *)obj;
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Rename The Sharing Alias", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.keyboardType = UIKeyboardTypeDefault;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            if (sharingInfo.alias.length > 0) {
                textField.text = sharingInfo.alias;
            } else {
                textField.text = [GosSharingManagerViewController userNameFromUserInfo:sharingInfo.userInfo];
            }
        }];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil) style:UIAlertActionStyleCancel handler:nil]];
        __weak __typeof(self)weakSelf = self;
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            showHUDAddedTo(strongSelf.view, YES);
            [GizDeviceSharing modifySharingInfo:[GosCommon sharedInstance].token sharingID:sharingInfo.id sharingAlias:alertController.textFields.firstObject.text];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)didGetDeviceSharingInfos:(NSError *)result deviceID:(NSString *)deviceID deviceSharingInfos:(NSArray *)deviceSharingInfos {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        //将列表信息按照更新时间排序
        __block NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
        self.list = [deviceSharingInfos sortedArrayUsingComparator:^NSComparisonResult(GizDeviceSharingInfo *_Nonnull obj1, GizDeviceSharingInfo *_Nonnull obj2) {
            NSDate *date1 = [GosCommon serviceDateFromString:obj1.updatedAt];
            NSDate *date2 = [GosCommon serviceDateFromString:obj2.updatedAt];
            return (date1.timeIntervalSince1970 > date2.timeIntervalSince1970);
        }];
        [self autoReloadTableView];
    } else {
        [[GosCommon sharedInstance] showAlert:[[GosCommon sharedInstance] checkErrorCode:result.code] disappear:YES];
    }
}

- (void)didGetBindingUsers:(NSError *)result deviceID:(NSString *)deviceID bindUsers:(NSArray *)bindUsers {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        //将列表信息按照更新时间排序
        __block NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
        self.list = [bindUsers sortedArrayUsingComparator:^NSComparisonResult(GizUserInfo *_Nonnull obj1, GizUserInfo *_Nonnull obj2) {
            NSDate *date1 = [GosCommon serviceDateFromString:obj1.deviceBindTime];
            NSDate *date2 = [GosCommon serviceDateFromString:obj2.deviceBindTime];
            return (date1.timeIntervalSince1970 > date2.timeIntervalSince1970);
        }];
        [self autoReloadTableView];
    } else {
        [[GosCommon sharedInstance] showAlert:[[GosCommon sharedInstance] checkErrorCode:result.code] disappear:YES];
    }
}

- (void)didUnbindUser:(NSError *)result deviceID:(NSString *)deviceID guestUID:(NSString *)guestUID {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onBindUsers:nil];
    } else {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Your request is failed", nil) disappear:YES];
    }
}

- (void)didRevokeDeviceSharing:(NSError *)result sharingID:(NSInteger)sharingID {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onUpdateSharingList];
    } else {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Your request is failed", nil) disappear:YES];
    }
}

- (void)didModifySharingInfo:(NSError *)result sharingID:(NSInteger)sharingID {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onUpdateSharingList];
    } else {
        [[GosCommon sharedInstance] showAlert:[[GosCommon sharedInstance] checkErrorCode:result.code] disappear:YES];
    }
}

- (void)didSharingDevice:(NSError *)result deviceID:(NSString *)deviceID sharingID:(NSInteger)sharingID QRCodeImage:(UIImage *)QRCodeImage {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onUpdateSharingList];
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
