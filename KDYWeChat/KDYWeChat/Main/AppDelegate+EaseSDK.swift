//
//  AppDelegate+EaseSDK.swift
//  KDYWeChat
//
//  Created by mac on 16/9/30.
//  Copyright © 2016年 kaideyi.com. All rights reserved.
//

import Foundation

extension AppDelegate {
    
    /**
     *  配置环信sdk
     */
    func easemobApplication(application: UIApplication,
                            launchOptions: [NSObject: AnyObject]?,
                            appKey: String,
                            apnsCerName: String,
                            otherConfig: [NSObject: AnyObject]?) {
        
        // 登录状态通知
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(AppDelegate.loginStateChanged(_:)),
                                                         name: "loginStateChanged",
                                                         object: nil)
        
        // 初始化sdk
        EaseSDKHelper.shareInstance.hyphenateApplication(application,
                                                         launchOptions: launchOptions,
                                                         appkey: appKey,
                                                         apnsCerName: apnsCerName,
                                                         otherConfig: nil)
        
        // 初始化 KDYChatHelper 单例类
        KDYChatHelper.shareInstance.initHeapler()
        
        // 根据用户是否自动登录，来发送登录状态的通知
        let isAutoLogin = EMClient.sharedClient().isAutoLogin
        if isAutoLogin {
            NSNotificationCenter.defaultCenter().postNotificationName("loginStateChanged", object: NSNumber(bool: true))
        } else {
            NSNotificationCenter.defaultCenter().postNotificationName("loginStateChanged", object: NSNumber(bool: false))
        }
    }
    
    /**
     *  登录状态改变
     */
    func loginStateChanged(notification: NSNotification) {
        let loginState = (notification.object?.boolValue)!
        if loginState {  // 登录成功
            KDYChatHelper.shareInstance.asyncPushOptions()
            KDYChatHelper.shareInstance.asyncConversationFromDB()
            
        } else {   // 登录失败
            
        }
    }
    
    // MARK: - AppDelegate
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // 注册远程通知成功，交给SDK并绑定
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { 
            EMClient.sharedClient().bindDeviceToken(deviceToken)
        }
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        // 注册远程通知失败，若有失败看看环境配置或证书是否有误！
        let alertView = UIAlertView.init(title: "注册APN失败",
                                         message: error.debugDescription,
                                         delegate: nil,
                                         cancelButtonTitle: "确定"
                                         )
        alertView.show()
    }
}

