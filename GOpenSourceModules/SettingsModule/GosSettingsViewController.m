//
//  SettingsViewController.m
//  GBOSA
//
//  Created by Zono on 16/5/12.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosSettingsViewController.h"
#import "GosCommon.h"

#import "GosUserLoginCell.h"
#import "GosUserManagementCell.h"

@interface GosSettingsViewController ()

@end

@implementation GosSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    self.automaticallyAdjustsScrollViewInsets = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - table view
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 56;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellIdentifier"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CellIdentifier"];
    }
    if (indexPath.section == 0) {
        cell.textLabel.text = NSLocalizedString(@"About", nil);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
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
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [self performSegueWithIdentifier:@"toAbout" sender:self];
    } else if (indexPath.section == 1) {
        if ([GosCommon sharedInstance].currentLoginStatus == GizLoginUser) {
            UINavigationController *nav = [[UIStoryboard storyboardWithName:@"GosUserManager" bundle:nil] instantiateInitialViewController];
            UIViewController *userManagerController = nav.viewControllers.firstObject;
            [self.navigationController pushViewController:userManagerController animated:YES];
        } else {
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
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
