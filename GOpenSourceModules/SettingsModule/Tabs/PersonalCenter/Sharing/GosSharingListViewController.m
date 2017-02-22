//
//  GosSharingListViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosSharingListViewController.h"
#import "GosSharingMessageCell.h"
#import "GosCommon.h"
#import "GosSharingManagerViewController.h"

@interface GosSharingListViewController () <UITableViewDelegate, UITableViewDataSource, GizDeviceSharingDelegate>

@property (weak, nonatomic) IBOutlet UIButton *btnSharing;
@property (weak, nonatomic) IBOutlet UIButton *btnMessage;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSArray *list;

@end

@implementation GosSharingListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self onSharing:nil];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [GizDeviceSharing setDelegate:self];
}

- (IBAction)onSharing:(id)sender { //共享选项卡
    self.btnSharing.selected = YES;
    self.btnMessage.selected = NO;
    
    NSMutableArray *deviceList = [NSMutableArray array];
    for (GizWifiDevice *device in [GizWifiSDK sharedInstance].deviceList) {
        if (device.sharingRole == GizDeviceSharingOwner ||
            device.sharingRole == GizDeviceSharingSpecial) {
            [deviceList addObject:device];
        }
    }
    self.list = deviceList;
    [self.tableView reloadData];
}

- (IBAction)onMessage:(id)sender { //受邀选项卡
    self.btnSharing.selected = NO;
    self.btnMessage.selected = YES;
    showHUDAddedTo(self.view, YES);
    [GizDeviceSharing getDeviceSharingInfos:[GosCommon sharedInstance].token sharingType:GizDeviceSharingToMe deviceID:nil];
}

#pragma mark - 
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.list.count == 0) {
        return 1;
    }
    return self.list.count;
}

- (UITableViewCell *)defaultCell {
    static NSString *identifier = @"DeviceIdentifier";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    cell.detailTextLabel.text = nil;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.list.count) {
        id obj = self.list[self.list.count-indexPath.row-1];
        if ([obj isKindOfClass:[GizWifiDevice class]]) {
            GizWifiDevice *device = (GizWifiDevice *)obj;
            UITableViewCell *cell = [self defaultCell];
            for (UIImageView *subview in cell.imageView.subviews) {
                if ([subview isMemberOfClass:[UIImageView class]]) {
                    [subview removeFromSuperview];
                }
            }
            
            //左侧图片
            UIGraphicsBeginImageContext(CGSizeMake(48, 48));
            UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            UIImageView *subImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"08-icon-Device"]];
            CGRect frame = subImageView.frame;
            
            frame.origin = CGPointMake(4, 6);
            subImageView.frame = frame;
            
            [cell.imageView addSubview:subImageView];
            cell.imageView.image = blankImage;
            cell.imageView.layer.cornerRadius = 10;
            
            cell.imageView.backgroundColor = CUSTOM_YELLOW_COLOR();

            cell.textLabel.text = device.alias;
            if (cell.textLabel.text.length == 0) {
                cell.textLabel.text = device.productName;
            }
            cell.detailTextLabel.text = device.macAddress;
            return cell;
        } else if ([obj isKindOfClass:[GizDeviceSharingInfo class]]) {
            static NSString *sharingIdentifier = @"sharingIdentifier";
            GosSharingMessageCell *messageCell = GetControllerWithClass([GosSharingMessageCell class], tableView, sharingIdentifier);
            messageCell.sharingInfo = obj;
            messageCell.listView = self.view;
            return messageCell;
        }
    } else {
        UITableViewCell *cell = [self defaultCell];
        for (UIImageView *subview in cell.imageView.subviews) {
            if ([subview isMemberOfClass:[UIImageView class]]) {
                [subview removeFromSuperview];
            }
        }
        cell.imageView.image = nil;
        
        if (self.btnSharing.selected) {
            cell.textLabel.text = NSLocalizedString(@"You have no device", nil);
        } else {
            cell.textLabel.text = NSLocalizedString(@"You have no invited message", nil);
        }
        return cell;
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.btnSharing.selected) {
        return (self.list.count > 0);
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.btnSharing.selected) {
        GizWifiDevice *device = self.list[self.list.count-indexPath.row-1];
        if ([device isKindOfClass:[GizWifiDevice class]]) {
            [self performSegueWithIdentifier:@"toManage" sender:device];
        } else {
            GIZ_LOG_ERROR("invalid list: %s", self.list.description);
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)didGetDeviceSharingInfos:(NSError *)result deviceID:(NSString *)deviceID deviceSharingInfos:(NSArray *)deviceSharingInfos {
    if (self.btnMessage.selected) {
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
        } else {
            self.list = nil;
            [[GosCommon sharedInstance] showAlert:[[GosCommon sharedInstance] checkErrorCode:result.code] disappear:YES];
        }
        [self.tableView reloadData];
    }
}

- (void)didAcceptDeviceSharing:(NSError *)result sharingID:(NSInteger)sharingID {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (result.code == GIZ_SDK_SUCCESS) {
        [self onMessage:nil];
    } else {
        [[GosCommon sharedInstance] showAlert:NSLocalizedString(@"Your request is failed", nil) disappear:YES];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isMemberOfClass:[GosSharingManagerViewController class]]) {
        GosSharingManagerViewController *managerCtrl = (GosSharingManagerViewController *)segue.destinationViewController;
        managerCtrl.device = sender;
    }
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
