//
//  GosUserManagementCell.m
//  GOpenSource_AppKit
//
//  Created by Tom Ge on 2016/11/18.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosUserManagementCell.h"

@implementation GosUserManagementCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
