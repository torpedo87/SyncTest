//
//  PhotoCell.swift
//  Syncable
//
//  Created by junwoo on 09/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit

protocol PhotoCellDelegate {
  func photoDelete(cell: UICollectionViewCell)
}

class PhotoCell: UICollectionViewCell {
  
  @IBOutlet weak var imgView: UIImageView!
  var delegate: PhotoCellDelegate?
  
  func configure(photo: UIImage) {
    imgView.image = photo
  }
  
  @IBAction func deleteButtonTapped(_ sender: Any) {
    delegate?.photoDelete(cell: self)
  }
  
}
