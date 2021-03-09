//
//  TransformerExampleViewController.swift
//  FSPagerViewExample
//
//  Created by Wenchao Ding on 09/01/2017.
//  Copyright © 2017 Wenchao Ding. All rights reserved.
//

import UIKit
import SwiftBrick
class TransformerExampleViewController: JHTableViewController,PageViewDataSource,PageViewDelegate {
    
    fileprivate let imageNames =  ["1","2","3","4","5","6"]
    fileprivate let transformerNames = ["cross fading", "zoom out", "depth", "linear", "overlap", "ferris wheel", "inverted ferris wheel", "coverflow", "cubic"]
    fileprivate let transformerTypes: [TransformerType] = [.crossFading,
                                                                      .zoomOut,
                                                                      .depth,
                                                                      .linear,
                                                                      .overlap,
                                                                      .ferrisWheel,
                                                                      .invertedFerrisWheel,
                                                                      .coverFlow,
                                                                      .cubic]
    fileprivate var typeIndex = 0 {
        didSet {
            let type = self.transformerTypes[typeIndex]
            banner.transformer = Transformer(type:type)
            switch type {
            case .crossFading, .zoomOut, .depth:
                banner.itemSize = PageView.automaticSize
                banner.decelerationDistance = 1
            case .linear, .overlap:
                let transform = CGAffineTransform(scaleX: 0.6, y: 0.75)
                banner.itemSize = banner.frame.size.applying(transform)
                banner.decelerationDistance = PageView.automaticDistance
            case .ferrisWheel, .invertedFerrisWheel:
                banner.itemSize = CGSize(width: 180, height: 140)
                banner.decelerationDistance = PageView.automaticDistance
            case .coverFlow:
                banner.itemSize = CGSize(width: 220, height: 170)
                banner.decelerationDistance = PageView.automaticDistance
            case .cubic:
                let transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                banner.itemSize = banner.frame.size.applying(transform)
                banner.decelerationDistance = 1
            }
        }
    }
    
    lazy var banner: PageView = {
        let banner = PageView()
        banner.dataSource = self
        banner.delegate = self
        banner.automaticSlidingInterval = 3
        banner.registerCell(LabelViewCell.self)
        banner.registerCell(CollectionViewCell.self)
        banner.itemSize = CGSize(width: UIScreen.main.bounds.width, height: 100)
        return banner
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Banner 滚动样式"
        
        view.addSubview(banner)
        banner.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(100)
            m.left.right.equalToSuperview()
            m.height.equalTo(250)
        }
        
        tableView?.snp.remakeConstraints({ (m) in
            m.bottom.left.right.equalToSuperview()
            m.top.equalTo(banner.snp.bottom).offset(20)
        })
        
        tableView?.registerCell(TableViewCell.self)
        
        let index = self.typeIndex
        self.typeIndex = index // Manually trigger didSet
        mainDatas = ["cross fading", "zoom out", "depth", "linear", "overlap", "ferris wheel", "inverted ferris wheel", "coverflow", "cubic"]
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(JHTableViewCell.self)
        cell.textLabel?.text = self.transformerNames[indexPath.row]
        cell.accessoryType = indexPath.row == self.typeIndex ? .checkmark : .none
        return cell
    }
    
    // MARK:- UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.typeIndex = indexPath.row
        if let visibleRows = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: visibleRows, with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Transformers"
    }
    
    // MARK:- FSPagerViewDataSource
    
    func numberOfItems(in pageView: PageView) -> Int {
        return imageNames.count
    }
    
    func pageView(_ pageView: PageView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CollectionViewCell = pageView.dequeueReusableCell(CollectionViewCell.self, indexPath: indexPath)
         let name = imageNames[indexPath.row]
            cell.imageView.image = UIImage(named: name)
            cell.titleLab.text = name
        
        return cell
    }
    

    
}
