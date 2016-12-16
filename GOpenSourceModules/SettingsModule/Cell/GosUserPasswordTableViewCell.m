//
//  GosUserPasswordTableViewCell.m
//  GOpenSource_AppKit
//
//  Created by Tom Ge on 2016/11/18.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosUserPasswordTableViewCell.h"

@implementation GosUserPasswordTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)onShow:(UIButton *)sender {
    self.textPassword.secureTextEntry = !self.textPassword.secureTextEntry;
    sender.selected = !self.textPassword.secureTextEntry;
}

@end
