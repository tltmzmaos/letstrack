//
//  TableViewCell.swift
//  Extr
//
//  Created by Jongmin Lee on 1/25/20.
//  Copyright © 2020 Jongmin Lee. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {

    @IBOutlet weak var amount: UILabel!
    @IBOutlet weak var category: UIImageView!
    @IBOutlet weak var notes: UILabel!
    @IBOutlet weak var categoryL: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
