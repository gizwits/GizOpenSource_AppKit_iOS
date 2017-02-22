//
//  GosConfigModuleSelection.m
//  GOpenSource_AppKit
//
//  Created by Tom on 2017/2/6.
//  Copyright © 2017年 Gizwits. All rights reserved.
//

#import "GosConfigModuleSelection.h"
#import "GosCommon.h"
#import "GosConfigAirlinkTips.h"

@interface GosConfigModuleSelection () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (strong, nonatomic) NSArray *list;
@property (strong, nonatomic) NSArray *listText;

@end

@implementation GosConfigModuleSelection

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Register cell classes
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    self.list = [GosCommon sharedInstance].configModuleValueArray;
    self.listText = [GosCommon sharedInstance].configModuleTextArray;
    
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(NSString *)sender {
    if ([segue.destinationViewController isMemberOfClass:[GosConfigAirlinkTips class]]) {
        GosConfigAirlinkTips *tipsCtrl = (GosConfigAirlinkTips *)segue.destinationViewController;
        tipsCtrl.selectedModuleName = sender;
    }
}

- (IBAction)onBack:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark <UICollectionViewDataSource>

- (UIView *)makeView:(NSString *)text image:(UIImage *)image isSelected:(BOOL)isSelected {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 95, 110)];
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 95, 100)];
    if (isSelected) {
        backgroundView.backgroundColor = [UIColor lightGrayColor];
    } else {
        backgroundView.backgroundColor = [UIColor whiteColor];
    }
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 10, 85, 64)];//4:3 or other?
    imageView.image = image;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 80, 95, 20)];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:14];
    label.text = text;
    [view addSubview:backgroundView];
    [view addSubview:imageView];
    [view addSubview:label];
    return view;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return MIN(self.list.count, self.listText.count);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    NSString *text = self.listText[indexPath.row];
    GizWifiGAgentType gagentType = [self.list[indexPath.row] integerValue];
    UIImage *image = nil;
    switch (gagentType) {
        case GizGAgentESP:
            image = [UIImage imageNamed:@"ESP.jpg"];
            break;
        case GizGAgentMXCHIP:
            image = [UIImage imageNamed:@"MXCHIP.jpg"];
            break;
        case GizGAgentHF:
            image = [UIImage imageNamed:@"HF.jpg"];
            break;
        case GizGAgentQCA:
            image = [UIImage imageNamed:@"QCA.jpg"];
            break;
        case GizGAgentRTK:
            image = [UIImage imageNamed:@"RTK.jpg"];
            break;
        case GizGAgentTI:
            image = [UIImage imageNamed:@"TI.jpg"];
            break;
        case GizGAgentWM:
            image = [UIImage imageNamed:@"WM.jpg"];
            break;
        default:
            image = [UIImage imageNamed:@"default.png"];
            break;
    }

    cell.backgroundView = [self makeView:text image:image isSelected:NO];
    cell.selectedBackgroundView = [self makeView:text image:image isSelected:YES];
    
    return cell;
}

#pragma mark UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    [GosCommon sharedInstance].airlinkConfigType = [self.list[indexPath.row] integerValue];
    [self performSegueWithIdentifier:@"toTips" sender:self.listText[indexPath.row]];
}

@end
