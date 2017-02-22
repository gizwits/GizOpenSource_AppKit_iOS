//
//  GosPersonalCenterTableViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosPersonalCenterTableViewController.h"
#import "GosCommon.h"

#import "GosUserLoginCell.h"
#import "GosUserManagementCell.h"

@interface GosPersonalCenterTableViewController ()

@property (strong, nonatomic, readonly) NSArray *firstGroupItems;

@end

@implementation GosPersonalCenterTableViewController

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.tableView.isDragging && !self.tableView.decelerating && self.tableView.contentOffset.y != -64) { //修复iOS8的显示问题
        self.tableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    _firstGroupItems = @[NSLocalizedString(@"Device Sharing", nil),
                         NSLocalizedString(@"About", nil)];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.navigationItem.title = self.tabBarItem.title;
    self.tabBarController.navigationItem.rightBarButtonItem = nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return self.firstGroupItems.count;
        case 1:
            return 1;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"personalIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    
    switch (indexPath.section) {
        case 0:
            cell.textLabel.text = self.firstGroupItems[indexPath.row];
            break;
        case 1:
            if ([GosCommon sharedInstance].currentLoginStatus == GizLoginUser) {
                GosUserManagementCell *cell = GetControllerWithClass([GosUserManagementCell class], tableView, @"GosUserManagerIdentifier");
                if ([GosCommon sharedInstance].isThirdAccount) {
                    NSString *uid = [GosCommon sharedInstance].uid;
                    NSString *uid_pre = [uid substringToIndex:2];
                    NSString *uid_end = [uid substringFromIndex:uid.length-4];
                    cell.textPhoneNumber.text = [NSString stringWithFormat:@"%@***%@", uid_pre, uid_end];
                } else {
                    cell.textPhoneNumber.text = [GosCommon sharedInstance].tmpUser;
                }
                return cell;
            } else {
                return GetControllerWithClass([GosUserLoginCell class], tableView, @"GosUserLoginIdentifier");
            }
            break;
        default:
            break;
    }
    // Configure the cell...
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section) {
        case 0:
            switch (indexPath.row) {
                case 0: {
                    UINavigationController *navCtrl = [[UIStoryboard storyboardWithName:@"GosSharing" bundle:nil] instantiateInitialViewController];
                    [self.tabBarController.navigationController pushViewController:navCtrl.viewControllers.firstObject animated:YES];
                    break;
                }
                case 1: {
                    UIViewController *aboutCtrl = [[UIStoryboard storyboardWithName:@"GosSettings" bundle:nil] instantiateViewControllerWithIdentifier:@"GosAbout"];
                    [self.tabBarController.navigationController pushViewController:aboutCtrl animated:YES];
                    break;
                }
                default:
                    break;
            }
            break;
        case 1:
            if ([GosCommon sharedInstance].currentLoginStatus == GizLoginUser) {
                UINavigationController *nav = [[UIStoryboard storyboardWithName:@"GosUserManager" bundle:nil] instantiateInitialViewController];
                UIViewController *userManagerController = nav.viewControllers.firstObject;
                [self.navigationController pushViewController:userManagerController animated:YES];
            } else {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
            break;
            
        default:
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
