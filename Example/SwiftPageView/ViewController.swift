//
//  ViewController.swift
//  SwiftPageView
//
//  Created by jackiehu on 09/25/2020.
//  Copyright (c) 2020 jackiehu. All rights reserved.
//

import UIKit
import SwiftPageView
import SnapKit
import JXPageControl
class ViewController: UIViewController{

    lazy var codePageControl: JXPageControlJump = {
        let pageControl = JXPageControlJump()
        // JXPageControlType: default property
        pageControl.currentPage = 0
        pageControl.progress = 0.0
        pageControl.hidesForSinglePage = false
        pageControl.inactiveColor = UIColor.white
        pageControl.activeColor = UIColor.red
        pageControl.inactiveSize = CGSize(width: 10, height: 10)
        pageControl.activeSize = CGSize(width: 20, height: 10)
        pageControl.columnSpacing = 10
        pageControl.contentAlignment = JXPageControlAlignment(.center,
                                                              .center)
        pageControl.contentMode = .center
        pageControl.isInactiveHollow = false
        pageControl.isActiveHollow = false
        pageControl.isAnimation  = true
        return pageControl
    }()
    
    lazy var banner: PageView = {
        let banner = PageView()
        banner.dataSource = self
        banner.delegate = self
        banner.automaticSlidingInterval = 3
        banner.backgroundColor = .cyan
        banner.interitemSpacing = 20
        banner.itemSize = CGSize(width: UIScreen.main.bounds.width-20, height: 100)
        banner.registerCell(CollectionViewCell.self)
        return banner
    }()
    
    var array : [String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(banner)
        banner.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(100)
            m.left.right.equalToSuperview()
            m.height.equalTo(200)
        }

        view.addSubview(codePageControl)
        codePageControl.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(100)
            m.left.right.equalToSuperview()
            m.height.equalTo(30)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now()+5) {
            self.array = ["1","2","3","4","5","6"]
            self.banner.reloadData()
            self.codePageControl.numberOfPages = self.array?.count ?? 0
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController:  PageViewDataSource, PageViewDelegate {
    
    func numberOfItems(in pageView: PageView) -> Int {
        guard let aa = array else {
            return 0
        }
        return aa.count
    }

    func pageView(_ pageView: PageView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: CollectionViewCell = pageView.dequeueReusableCell(CollectionViewCell.self, indexPath: indexPath)
        if let name = array?[indexPath.row] {
            cell.imageView.image = UIImage(named: name)
            cell.titleLab.text = name
        }
        
        cell.imageView.layer.cornerRadius = 10
        
        return cell
    }

    func pageView(_ pageView: PageView, willScrollToItemAt index: Int) {
        print("------\(index)")
    }

    func pageView(_ pageView: PageView, didSelectItemAt index: Int) {
        print("dianji\(index)")
    }

    func pageView(_ pageView: PageView, didScrollToItemAt index: Int) {
        print("gundongdao\(index)")
    }

    func pageViewDidScroll(_ pageView: PageView, scrollProgress: CGFloat) {
        codePageControl.progress = scrollProgress
    }


}

