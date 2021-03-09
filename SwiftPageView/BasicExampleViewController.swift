//
//  ViewController.swift
//  FSPagerViewExample
//
//  Created by Wenchao Ding on 17/12/2016.
//  Copyright © 2016 Wenchao Ding. All rights reserved.
//

import UIKit
import SwiftBrick
class BasicExampleViewController: JHTableViewController,PageViewDataSource,PageViewDelegate {
    
    fileprivate let sectionTitles = ["配置", "手动滚动距离", "大小", "间距"]
    fileprivate let configurationTitles = ["自动滚动","无限滚动"]
    fileprivate let decelerationDistanceOptions = ["自动", "1", "2"]
    fileprivate let imageNames = ["1","2","3","4","5","6"]
    fileprivate var numberOfItems = 6

    lazy var banner: PageView = {
        let banner = PageView()
        banner.dataSource = self
        banner.delegate = self
        banner.automaticSlidingInterval = 3
        banner.registerCell(LabelViewCell.self)
        banner.registerCell(CollectionViewCell.self)

        banner.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 150)
        return banner
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Banner 设置,样式"
        
        view.addSubview(banner)
        banner.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(100)
            m.left.right.equalToSuperview()
            m.height.equalTo(150)
        }
        
        tableView?.snp.remakeConstraints({ (m) in
            m.bottom.left.right.equalToSuperview()
            m.top.equalTo(banner.snp.bottom)
        })
        tableView?.sectionHeaderHeight = 30
        tableView?.registerCell(TableViewCell.self)
    }
    // MARK:- UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionTitles.count
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.configurationTitles.count
        case 1:
            return self.decelerationDistanceOptions.count
        case 2,3:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            // Configurations
            let cell = tableView.dequeueReusableCell(JHTableViewCell.self)
            cell.textLabel?.text = configurationTitles[indexPath.row]
            if indexPath.row == 0 {
                // Automatic Sliding
                cell.accessoryType = banner.automaticSlidingInterval > 0 ? .checkmark : .none
            } else if indexPath.row == 1 {
                // IsInfinite
                cell.accessoryType = banner.isInfinite ? .checkmark : .none
            }
            return cell
        case 1:
            // Decelaration Distance
            let cell = tableView.dequeueReusableCell(JHTableViewCell.self)
            cell.textLabel?.text = decelerationDistanceOptions[indexPath.row]
            switch indexPath.row {
            case 0:
                cell.accessoryType = banner.decelerationDistance == PageView.automaticDistance ? .checkmark : .none
            case 1:
                cell.accessoryType = banner.decelerationDistance == 1 ? .checkmark : .none
            case 2:
                cell.accessoryType = banner.decelerationDistance == 2 ? .checkmark : .none
            default:
                break;
            }
            return cell;
        case 2:
            // Item Spacing
            let cell = tableView.dequeueReusableCell(TableViewCell.self)
            let slider = cell.contentView.subviews.first as! UISlider
            slider.tag = 1
            slider.value = {
                let scale: CGFloat = banner.itemSize.width/banner.frame.width
                let value: CGFloat = (0.5-scale)*2
                return Float(value)
            }()
            slider.isContinuous = true
            slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .allEvents)
            return cell
        case 3:
            // Interitem Spacing
            let cell = tableView.dequeueReusableCell(TableViewCell.self)
            let slider = cell.contentView.subviews.first as! UISlider
            slider.tag = 2
            slider.value = Float(banner.interitemSpacing/20.0)
            slider.isContinuous = true
            slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .allEvents)
            return cell

        default:
            break
        }
        return tableView.dequeueReusableCell(JHTableViewCell.self)
    }
    
    // MARK:- UITableViewDelegate
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 || indexPath.section == 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 { // Automatic Sliding
                banner.automaticSlidingInterval = 3.0 - banner.automaticSlidingInterval
            } else if indexPath.row == 1 { // IsInfinite
                banner.isInfinite = !banner.isInfinite
            }
            tableView.reloadSections([indexPath.section], with: .automatic)
        case 1:
            switch indexPath.row {
            case 0:
                banner.decelerationDistance = PageView.automaticDistance
            case 1:
                banner.decelerationDistance = 1
            case 2:
                banner.decelerationDistance = 2
            default:
                break
            }
            tableView.reloadSections([indexPath.section], with: .automatic)
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let lab = UILabel()
        lab.text = sectionTitles[section]
        return lab
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    // MARK:- FSPagerView DataSource
    
    func numberOfItems(in pageView: PageView) -> Int {
        return self.numberOfItems
    }
    
    func pageView(_ pageView: PageView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CollectionViewCell = pageView.dequeueReusableCell(CollectionViewCell.self, indexPath: indexPath)
         let name = imageNames[indexPath.row]
            cell.imageView.image = UIImage(named: name)
            cell.titleLab.text = name
        
        return cell
    }

    @objc
    func sliderValueChanged(_ sender: UISlider) {
        switch sender.tag {
        case 1:
            let newScale = 0.5+CGFloat(sender.value)*0.5 // [0.5 - 1.0]
            banner.itemSize = banner.frame.size.applying(CGAffineTransform(scaleX: newScale, y: newScale))
        case 2:
            banner.interitemSpacing = CGFloat(sender.value) * 20 // [0 - 20]
        default:
            break
        }
    }
}


