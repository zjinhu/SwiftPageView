//
//  TableViewCell.swift
//  SwiftPageView
//
//  Created by iOS on 2021/3/9.
//

import UIKit
import SwiftBrick
class TableViewCell: JHTableViewCell {

    var slider = UISlider()

    override func setupCellViews() {
        slider.frame = bounds
        contentView.addSubview(slider)
    }
}
