//
//  CollectionViewCell.swift
//  SwiftBannerView_Example
//
//  Created by iOS on 2020/8/27.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    public var titleLab = UILabel()
    public var imageView = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.clipsToBounds = true
        imageView.frame = bounds
        contentView.addSubview(imageView)
        
        titleLab.frame = bounds
        contentView.addSubview(titleLab)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
