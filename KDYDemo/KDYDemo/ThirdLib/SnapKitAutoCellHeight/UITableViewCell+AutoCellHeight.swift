//
//  UITableView+AutoCellHeight.swift
//  demo
//
//  Created by huangyibiao on 16/1/16.
//  Copyright © 2016年 huangyibiao. All rights reserved.
//

import Foundation
import UIKit

private var __hyb_lastViewInCellKey  = "__hyb_lastViewInCellKey"
private var __hyb_bottomOffsetToCell = "__hyb_bottomOffsetToCell"

///
/// 基于SnapKit扩展自动计算cell的高度
///
/// 作者：黄仪标
/// GITHUB：[HYBSnapkitAutoCellHeight](https://github.com/CoderJackyHuang/HYBSnapkitAutoCellHeight)
/// 作者博客：[标哥的技术博客](http://www.henishuo.com)
/// 作者微博：[标哥Jacky](http://weibo.com/u/5384637337)
private let __currentVersion = "1.0"

extension UITableViewCell {
    /// 所指定的距离cell底部较近的参考视图，必须指定，若不指定则会assert失败
    public var hyb_lastViewInCell: UIView? {
        get {
            let lastView = objc_getAssociatedObject(self, &__hyb_lastViewInCellKey);
            return lastView as? UIView
        }
        
        set {
            objc_setAssociatedObject(self,
                &__hyb_lastViewInCellKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    /// 可不指定，若不指定则使用默认值0
    public var hyb_bottomOffsetToCell: CGFloat? {
        get {
            let offset = objc_getAssociatedObject(self, &__hyb_bottomOffsetToCell);
            return offset as? CGFloat
        }
        
        set {
            objc_setAssociatedObject(self,
                &__hyb_bottomOffsetToCell,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN);
        }
    }
    
    /**
     唯一的类方法，用于计算行高
     
     - parameter indexPath:	index path
     - parameter config:		在config中调用配置数据方法等
     
     - returns: 所计算得到的行高
     */
    public class func hyb_cellHeight(forIndexPath indexPath: NSIndexPath, config: ((cell: UITableViewCell) -> Void)?) -> CGFloat {
        let cell = self.init(style: .Default, reuseIdentifier: nil)
        
        if let block = config {
            block(cell: cell);
        }
        
        return cell.hyb_calculateCellHeight(forIndexPath: indexPath, cache: nil)
    }
    
    /**
     带缓存功能、自动计算行高
     
     - parameter indexPath:					index path
     - parameter config:						在回调中配置数据
     - parameter cache:							指定缓存key/stateKey/tableview
     - parameter stateKey:					stateKey表示状态key
     - parameter cacheForTableView: 指定给哪个tableview缓存
     
     - returns: 行高
     */
    public class func hyb_cellHeight(forIndexPath indexPath: NSIndexPath,
        config: ((cell: UITableViewCell) -> Void)?,
        cache: ((Void) -> (key: String, stateKey: String, cacheForTableView: UITableView))?) -> CGFloat {
            if cache != nil {
                return self.hyb_cellHeight(forIndexPath: indexPath, config: config, updateCacheIfNeeded: { () -> (key: String, stateKey: String, shouldUpdate: Bool, cacheForTableView: UITableView) in
                    let cacheGroup = cache!()
                    return (cacheGroup.key, cacheGroup.stateKey, false, cacheGroup.cacheForTableView)
                })
            }
            
            return self.hyb_cellHeight(forIndexPath: indexPath, config: config, updateCacheIfNeeded: nil)
    }
    
    /**
     带缓存功能、自动计算行高
     
     - parameter indexPath:					index path
     - parameter config:						在回调中配置数据
     - parameter cache:							指定缓存key/stateKey/tableview
     - parameter stateKey:					stateKey表示状态key
     - parameter shouldUpdate       是否要更新指定stateKey中缓存高度，若为YES,不管有没有缓存 ，都会重新计算
     - parameter cacheForTableView: 指定给哪个tableview缓存
     
     - returns: 行高
     */
    public class func hyb_cellHeight(forIndexPath indexPath: NSIndexPath,
        config: ((cell: UITableViewCell) -> Void)?,
        updateCacheIfNeeded cache: ((Void) -> (key: String, stateKey: String, shouldUpdate: Bool, cacheForTableView: UITableView))?) -> CGFloat {
            
            if let cacheBlock = cache {
                let keyGroup = cacheBlock()
                let key = keyGroup.key
                let stateKey = keyGroup.stateKey
                let tableView = keyGroup.cacheForTableView
                let shouldUpdate = keyGroup.shouldUpdate;
                
                if shouldUpdate == false {
                    if  let cacheDict = tableView.hyb_cacheHeightDictionary {
                        // 状态高度缓存
                        if let stateDict = cacheDict[key] as? NSMutableDictionary {
                            if let height = stateDict[stateKey] as? NSNumber {
                                if height.intValue != 0 {
                                    return CGFloat(height.floatValue)
                                }
                            }
                        }
                    }
                }
            }
            
            let cell = self.init(style: .Default, reuseIdentifier: nil)
            if let block = config {
                block(cell: cell);
            }
            
            return cell.hyb_calculateCellHeight(forIndexPath: indexPath, updateCacheIfNeeded: cache)
    }
    
    // MARK: Private
    private func hyb_calculateCellHeight(forIndexPath indexPath: NSIndexPath,
        cache: ((Void) -> (key: String, stateKey: String, cacheForTableView: UITableView))?) -> CGFloat {
            if cache != nil {
                return hyb_calculateCellHeight(forIndexPath: indexPath, updateCacheIfNeeded: { () -> (key: String, stateKey: String, shouldUpdate: Bool, cacheForTableView: UITableView) in
                    let cacheGroup = cache!()
                    return (cacheGroup.key, cacheGroup.stateKey, false, cacheGroup.cacheForTableView)
                })
            } else {
                return hyb_calculateCellHeight(forIndexPath: indexPath, updateCacheIfNeeded: nil)
            }
    }
    
    private func hyb_calculateCellHeight(forIndexPath indexPath: NSIndexPath,
        updateCacheIfNeeded cache: ((Void) -> (key: String, stateKey: String, shouldUpdate: Bool, cacheForTableView: UITableView))?) -> CGFloat {
            assert(self.hyb_lastViewInCell != nil, "hyb_lastViewInCell property can't be nil")
            
            layoutIfNeeded()
            
            var height = self.hyb_lastViewInCell!.frame.origin.y + self.hyb_lastViewInCell!.frame.size.height;
            height += self.hyb_bottomOffsetToCell ?? 0.0
            
            if let cacheBlock = cache {
                let keyGroup = cacheBlock()
                let key = keyGroup.key
                let stateKey = keyGroup.stateKey
                let tableView = keyGroup.cacheForTableView
                
                if let cacheDict = tableView.hyb_cacheHeightDictionary {
                    // 状态高度缓存
                    let stateDict = cacheDict[key] as? NSMutableDictionary
                    
                    if stateDict != nil {
                        stateDict?[stateKey] = NSNumber(float: Float(height))
                    } else {
                        cacheDict[key] = NSMutableDictionary(object: NSNumber(float: Float(height)), forKey: stateKey)
                    }
                }
            }
            
            return height
    }
}

