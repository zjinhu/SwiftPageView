//
//  BannerCell.swift
//  SwiftBannerView
//
//  Created by iOS on 2020/8/26.
//

import UIKit
///内置基础样式,更多样式请自定义,并注册
public class PageCell: UICollectionViewCell {
    public var imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.clipsToBounds = true
        imageView.frame = bounds
        contentView.addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
