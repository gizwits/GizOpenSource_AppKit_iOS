//
//  GosUserManagerViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom Ge on 2016/11/18.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosUserManagerViewController.h"

#import "GosCommon.h"
#import "GosPushManager.h"
#import "GosAnonymousLogin.h"

#import "GosUserLogoutTableViewCell.h"

@interface GosUserManagerViewController () <UIAlertViewDelegate>

@end

@implementation GosUserManagerViewController

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

- (void)onUserLogout {
    if ([GosCommon sharedInstance].currentLoginStatus == GizLoginUser) {
#if USE_UMENG
        [MobClick event:@"more_actionsheet_logout"];
#endif
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"tip", nil) message:NSLocalizedString(@"Logout?", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"OK", nil), nil];
        [alertView show];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            //第三方账户不能修改密码
            if ([GosCommon sharedInstance].isThirdAccount) {
                return 1;
            }
            return 2;
            
        default:
            break;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.section) {
        case 0: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"userManagerIdentifier" forIndexPath:indexPath];
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = NSLocalizedString(@"User Account", @"用户账号");
                    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 56)];
                    label.textAlignment = NSTextAlignmentRight;
                    label.textColor = [UIColor colorWithRed:0.5976 green:0.5976 blue:0.5976 alpha:1];
                    if ([GosCommon sharedInstance].isThirdAccount) {
                        NSString *uid = [GosCommon sharedInstance].uid;
                        NSString *uid_pre = [uid substringToIndex:2];
                        NSString *uid_end = [uid substringFromIndex:uid.length-4];
                        label.text = [NSString stringWithFormat:@"%@***%@", uid_pre, uid_end];
                    } else {
                        label.text = [GosCommon sharedInstance].tmpUser;
                    }
                    cell.accessoryView = label;
                    break;
                }
                case 1:
                    cell.textLabel.text = NSLocalizedString(@"Edit password", @"修改密码");
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.accessoryView = nil;
                    break;
                    
                default:
                    break;
            }
            return cell;
        }
        case 1:
            return GetControllerWithClass([GosUserLogoutTableViewCell class], tableView, @"GosUserLogoutTableViewCellIdentifier");
        default:
            break;
    }
    
    // Configure the cell...
    
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0 && indexPath.section == 0) {
        return NO;
    }
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.section) {
        case 0:
            if (indexPath.row == 1) {
                [self performSegueWithIdentifier:@"toChange" sender:self];
            }
            break;
        case 1:
            [self onUserLogout];
            break;
        default:
            break;
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    [GosPushManager unbindToGDMS:YES];
    [[GosCommon sharedInstance] removeUserDefaults];
    [GosCommon sharedInstance].currentLoginStatus = GizLoginNone;
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
