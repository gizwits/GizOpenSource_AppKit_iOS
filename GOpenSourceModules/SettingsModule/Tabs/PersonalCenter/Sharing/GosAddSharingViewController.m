//
//  GosAddSharingViewController.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosAddSharingViewController.h"

@interface GosAddSharingViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation GosAddSharingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *firstIdentifier = @"firstIdentifier";
    static NSString *lastIdentifier = @"lastIdentifier";
    
    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:firstIdentifier forIndexPath:indexPath];
        cell.imageView.image = [UIImage imageNamed:@"scan.png"];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:lastIdentifier forIndexPath:indexPath];
        cell.imageView.image = [UIImage imageNamed:@"friends.png"];
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        [self performSegueWithIdentifier:@"toQRCode" sender:nil];
    } else {
        [self performSegueWithIdentifier:@"toAccount" sender:nil];
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
