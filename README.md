# 机智云物联网开源框架App
==================

    使用机智云物联网开源APP之前，需要先在机智云开发平台创建您自己的产品和应用。

    开源APP需要使用您申请的AppId、AppSecret以及您自己的产品ProductKey才能正常运行。

    具体申请流程请参见：http://docs.gizwits.com/hc/

    开源框架工程可通过修改配置文件配置开发者的个人应用信息，请参考使用说明中的 第5节 配置文件说明 进行替换。

    使用QQ、微信登录或百度或极光推送功能之前，需要您先到相应网站申请对应的应用信息，在配置文件中作相应的替换。


# GizWifiSDK 版本号

    2.05.05.21618


# 功能介绍

    本文档为机智云物联网开源基础App套件使用说明，旨在为机智云物联网开发者提供一个快速开发模板，可在此工程基础上快速开发智能设备App，或参考这里的相关代码进行开发。

## 目录结构说明

    > Lib：包括 GizWifiSDK 在内的的第三方库目录

    > GizOpenSourceModules：组成模块

    >> CommonModule // 公共方法类、资源文件 及 自定义 Cell
    
    >> ConfigModule // 设备配置模块，包含 AirLink 及 SoftAP
    
    >> UserModule // 用户模块，包含 用户登录、用户注册、找回密码
    
    >> DeviceModule // 设备模块，包含 设备列表
    
    >> SettingsModule // 设置模块，包含 设置菜单 及其 包含的子菜单项（关于等）

    >> PushModule // 推送模块，包含 百度和极光的推送SDK 集成封装
    
    
# 使用说明

## 1. 默认程序入口
    
    默认程序入口在 UserModule 中的 LoginViewController。

## 2. 更改启动后的载入界面
    
    如果要启动程序直接进入设备列表，可在 LoginViewController.m 文件的 “- (void)viewDidLoad” 方法中打开最后一行代码的注释:

	[self toDeviceListWithoutLogin:nil]


## 3. 加载控制界面
    
    代码位于 AppDelegate.m 文件中的 didFinishLaunchingWithOptions 方法第一行:

	[GosCommon sharedInstance].controlHandler = ^(GizWifiDevice device, UIViewController deviceListController) {
		GosDeviceController *devCtrl = [[GosDeviceController alloc] initWithDevice:device];
		[deviceListController.navigationController pushViewController:devCtrl animated:YES];
	};

    修改 GosDeviceController 类为开发者自己编写的控制界面的类即可。

## 4. 设置界面
    
    设置界面位于 SettingsModule 中的 GosSettingsViewController，按照 UITableView 实现官方的委托代理方法即可。

## 5. 配置文件说明

    配置文件位置：GOpenSourceModules/CommonModule/UIConfig.json

    配置文件可对程序样式及机智云appid等进行配置。

    可配置参数有：

	app_id：机智云 app id
	app_secret：机智云 app secret
	product_key：机智云 product key
	wifi_type_select：默认配置模块wifi模组选择功能是否开启
	tencent_app_id：qq登录 app id
	wechat_app_id：微信登录 app id
	wechat_app_secret：微信登录 app secret
	push_type：推送类型 【0：关闭，1：极光，2：百度】
	jpush_app_key：极光推送 app key
	bpush_app_key：百度推送 app key
	openAPIDomain：openAPI 域名及端口，格式：“api.gizwits.com”。要指定端口，格式为：”xxx.xxxxxxx.com:81&8443”
	siteDomain：site 域名及端口，格式：“site.gizwits.com”。要指定端口，格式为：”xxx.xxxxxxx.com:81&8443”
	pushDomain：推送绑定服务器 域名及端口，格式：“push.gizwits.com”。要指定端口，格式为：”xxx.xxxxxxx.com:81&8443”
	buttonColor：按钮颜色
	buttonTextColor：按钮文字颜色
	navigationBarColor：导航栏颜色
	navigationBarTextColor：导航栏文字颜色
	configProgressViewColor：配置中界面 progress view 颜色
	statusBarStyle：状态文字栏颜色 【0：黑色，1：白色】
	addDeviceTitle：添加设备界面 导航栏标题文字
    qq：是否打开QQ登录【true：打开】
    wechat：是否打开微信登录【true：打开】
    anonymousLogin：是否打开匿名登录【true：打开】

    具体细节可以参考【开源框架工程使用文档】：http://docs.gizwits.com/hc/kb/article/181715/

## 6. 第三方账号登录的使用

    使用微信、QQ登录功能，需要在info.plist设置URLScheme，登录完成后可从第三方应用跳回此应用

    使用QQ，把tencentxxx中的"xxx"换成UIConfig.json中对应的"tencent_app_id"字段的值
    使用微信，把"xxx"换成UIConfig.json中对应的"wechat_app_id"字段的值

# 程序调试

    您可以使用虚拟设备或者实体智能设备搭建调试环境。

    ▪	虚拟设备
        机智云官网提供GoKit虚拟设备的支持，链接地址：
	http://dev.gizwits.com/zh-cn/developer/product/

    ▪	实体设备
        GoKit开发板。您可以在机智云官方网站上免费预约申请，申请地址：
	http://www.gizwits.com/zh-cn/gokit
	
    GoKit开发板提供MCU开源代码供智能硬件设计者参考，请去此处下载：https://github.com/gizwits/gokit-mcu


# 问题反馈

    您可以给机智云的技术支持人员发送邮件，反馈您在使用过程中遇到的任何问题。
    邮箱：club@gizwits.com

    
