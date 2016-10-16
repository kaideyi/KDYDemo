//
//  KDMeViewController.swift
//  KDYWeChat
//
//  Created by kaideyi on 16/10/16.
//  Copyright © 2016年 kaideyi.com. All rights reserved.
//

import UIKit

/// 我界面
class KDMeViewController: UITableViewController {
    
    @IBOutlet var meTableView: UITableView!
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.meTableView.registerNib(UINib(nibName: "MeHeaderTableCell", bundle: nil), forCellReuseIdentifier: "MeHeaderTableCell")
    }
    
    // MARK: - UITableViewDataSoure
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let meHeaderCell = tableView.dequeueReusableCellWithIdentifier("MeHeaderTableCell", forIndexPath: indexPath)
            return meHeaderCell
            
        } else {
            var baseCell = tableView.dequeueReusableCellWithIdentifier("baseCell")
            if baseCell == nil {
                baseCell = UITableViewCell(style: .Default, reuseIdentifier: "baseCell")
            }
            
            baseCell?.accessoryType = .DisclosureIndicator
            baseCell?.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
            
            // 为什么在storyboard设置的没有显示出来？
            if indexPath.section == 1 {
                if indexPath.row == 0 {
                    baseCell?.textLabel?.text = "相册"
                    baseCell?.imageView?.image = UIImage(named: "MoreMyAlbum")
                } else if indexPath.row == 1 {
                    baseCell?.textLabel?.text = "收藏"
                    baseCell?.imageView?.image = UIImage(named: "MoreMyFavorites")
                } else if indexPath.row == 2 {
                    baseCell?.textLabel?.text = "钱包"
                    baseCell?.imageView?.image = UIImage(named: "MoreMyBankCard")
                } else {
                    baseCell?.textLabel?.text = "卡包"
                    baseCell?.imageView?.image = UIImage(named: "MyCardPackageIcon")
                }
                
            } else if indexPath.section == 2 {
                baseCell?.textLabel?.text = "表情"
                baseCell?.imageView?.image = UIImage(named: "MoreExpressionShops")
                
            } else {
                baseCell?.textLabel?.text = "设置"
                baseCell?.imageView?.image = UIImage(named: "MoreSetting")
            }
            
            return baseCell!
        }
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
       return 15
    }
}

