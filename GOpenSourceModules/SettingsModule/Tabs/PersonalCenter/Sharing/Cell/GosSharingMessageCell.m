//
//  GosSharingMessageCell.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2016/12/21.
//  Copyright © 2016年 Gizwits. All rights reserved.
//

#import "GosSharingMessageCell.h"
#import "GosCommon.h"
#import "GosSharingManagerViewController.h"
#import "GosMessageCenterTableViewController.h"

@interface GosSharingMessageCell()

@property (weak, nonatomic) IBOutlet UILabel *labelDetail;
@property (weak, nonatomic) IBOutlet UILabel *labelStatus;
@property (weak, nonatomic) IBOutlet UILabel *labelContent; //仅在viewDidLayoutSubviews使用，不要随意设置里面的值
@property (weak, nonatomic) IBOutlet UIButton *btnAccept;
@property (weak, nonatomic) IBOutlet UIButton *btnDecline;
@property (assign, nonatomic) BOOL isAcceptRequired;//请求接受还是超时

@end

@implementation GosSharingMessageCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self layoutIfNeeded];
    if (self.isAcceptRequired) { //小圆点
        [GosMessageCenterTableViewController markTableViewCell:self label:self.labelContent hasUnreadMessage:YES];
    } else {
        [GosMessageCenterTableViewController markTableViewCell:self label:self.labelContent hasUnreadMessage:NO];
    }
}

- (void)setSharingInfo:(GizDeviceSharingInfo *)sharingInfo {
    _sharingInfo = sharingInfo;
    //优先username，没有username找手机号，没手机号找邮箱，没邮箱找uid
    NSString *username = [GosSharingManagerViewController userNameFromUserInfo:sharingInfo.userInfo];
    NSString *deviceName = sharingInfo.deviceAlias;
    if (deviceName.length == 0) {
        deviceName = sharingInfo.productName;
    }
    
    self.labelContent.text = [NSString stringWithFormat:NSLocalizedString(@"invited_content_format", nil), username];
    NSDate *currentDate = [GosCommon serviceDateFromString:sharingInfo.updatedAt];
    NSDate *expiredDate = [GosCommon serviceDateFromString:sharingInfo.expiredAt];
    NSTimeInterval timerInterval = [expiredDate timeIntervalSinceNow];
    self.labelDetail.text = [NSString stringWithFormat:@"%@ %@", [GosCommon localDateStringFromDate:currentDate], deviceName];
    
    if (sharingInfo.status == GizDeviceSharingNotAccepted && timerInterval > 0) {
        self.labelStatus.hidden = YES;
        self.btnAccept.hidden = NO;
        self.btnDecline.hidden = NO;
        _isAcceptRequired = YES;
    } else {
        self.labelStatus.hidden = NO;
        self.btnAccept.hidden = YES;
        self.btnDecline.hidden = YES;
        _isAcceptRequired = NO;
        
        NSString *status = @"";
        switch (sharingInfo.status) {
            case GizDeviceSharingAccepted:
                status = NSLocalizedString(@"Accepted", nil);
                break;
            case GizDeviceSharingCancelled:
                status = NSLocalizedString(@"Cancelled", nil);
                break;
            case GizDeviceSharingRefused:
                status = NSLocalizedString(@"Refused", nil);
                break;
            case GizDeviceSharingNotAccepted:
                if (timerInterval < 0) {
                    status = NSLocalizedString(@"Timeout", nil);
                }
                break;
        }
        self.labelStatus.text = status;
    }
}

- (IBAction)onAccept:(id)sender { //接口事件在控制器中接收
    showHUDAddedTo(self.listView, YES);
    [GizDeviceSharing acceptDeviceSharing:[GosCommon sharedInstance].token sharingID:self.sharingInfo.id accept:YES];
}

- (IBAction)onDecline:(id)sender { //接口事件在控制器中接收
    showHUDAddedTo(self.listView, YES);
    [GizDeviceSharing acceptDeviceSharing:[GosCommon sharedInstance].token sharingID:self.sharingInfo.id accept:NO];
}

@end
