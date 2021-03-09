//
//  CollectionViewCell.swift
//  SwiftBannerView_Example
//
//  Created by iOS on 2020/8/27.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import SwiftBrick
class CollectionViewCell: JHCollectionViewCell {
    public var titleLab = UILabel()
    public var imageView = UIImageView()

    override func setupCellViews() {
        imageView.clipsToBounds = true

        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }

        contentView.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
}


class LabelViewCell: JHCollectionViewCell {
    public var titleLab = UILabel()
    
    override func setupCellViews() {
        titleLab.backgroundColor = .systemPink
        contentView.addSubview(titleLab)
        titleLab.snp.makeConstraints { (m) in
            m.edges.equalToSuperview()
        }
    }
}
