//
//  GosMessageCenterTableViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosMessageCenterTableViewController.h"
#import "GosSharingMessageTableViewController.h"

#import "GosCommon.h"

@interface GosMessageCenterTableViewController () <GizDeviceSharingDelegate>

@end

@implementation GosMessageCenterTableViewController

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.tableView.isDragging && !self.tableView.decelerating && self.tableView.contentOffset.y != -64) { //修复iOS8的显示问题
        self.tableView.contentInset = UIEdgeInsetsMake(64, 0, 0, 0);
    }
    
    NSArray *indexPaths = self.tableView.indexPathsForVisibleRows;
    for (NSIndexPath *indexPath in indexPaths) { //小圆点
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([GosCommon sharedInstance].sharingMessageList.count > 0) {
            BOOL hasUnreadMessage = NO;
            for (GizMessage *message in [GosCommon sharedInstance].sharingMessageList) {
                if (message.status == GizMessageUnread) {
                    hasUnreadMessage = YES;
                    break;
                }
            }
            
            [GosMessageCenterTableViewController markTableViewCell:cell label:cell.textLabel hasUnreadMessage:hasUnreadMessage];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.navigationItem.title = self.tabBarItem.title;
    self.tabBarController.navigationItem.rightBarButtonItem = nil;
    [GizDeviceSharing setDelegate:self];
    [GizDeviceSharing queryMessageList:[GosCommon sharedInstance].token messageType:GizMessageSharing];
    [self.tableView reloadData];
}

+ (void)markTableViewCell:(UITableViewCell *)cell label:(UILabel *)label hasUnreadMessage:(BOOL)hasUnreadMessage {
    for (UIView *view in cell.contentView.subviews) {
        if ([view isMemberOfClass:[UIImageView class]]) {
            [view removeFromSuperview];
        }
    }
    if (hasUnreadMessage) {
        CGSize fontSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
        CGRect realFrame = label.frame;
        CGFloat scale = 0.5f*label.contentScaleFactor;
        realFrame.size.width = realFrame.size.width * scale;
        
        if (fontSize.width > realFrame.size.width && realFrame.size.width != 0) {
            fontSize.width = realFrame.size.width;
        }
        
        UIGraphicsBeginImageContext(CGSizeMake(21, 21));
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetRGBFillColor(context, 1, 0, 0, 1);
        CGContextAddArc(context, 10, 10, 9, 0, 2*M_PI, 0);
        CGContextDrawPath(context, kCGPathFill);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        
        CGFloat left = fontSize.width+realFrame.origin.x+5;
        CGFloat top = realFrame.origin.y+(realFrame.size.height-label.font.pointSize)/2;
        if (realFrame.size.width != 0) {
            UIImageView *customView = [[UIImageView alloc] initWithFrame:CGRectMake(left, top, 7, 7)];
            customView.image = image;
            [cell.contentView addSubview:customView];
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"messageIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = NSLocalizedString(@"Device Sharing", nil);
            break;
        default:
            break;
    }
    
    // Configure the cell...
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row) {
        case 0: {
            GosSharingMessageTableViewController *sharingMessageCtrl = [[GosSharingMessageTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
            sharingMessageCtrl.navigationItem.title = NSLocalizedString(@"Device Sharing", nil);
            [self.tabBarController.navigationController pushViewController:sharingMessageCtrl animated:YES];
            break;
        }
            
        default:
            break;
    }
}

- (void)didQueryMessageList:(NSError *)result messageList:(NSArray *)messageList {
    if (result.code == GIZ_SDK_SUCCESS) {
        [GosCommon sharedInstance].sharingMessageList = messageList;
        [self.tableView reloadData];
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
