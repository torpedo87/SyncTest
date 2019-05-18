//
//  ListCell.swift
//  Syncable
//
//  Created by junwoo on 16/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit

protocol ListCellDelegate {
  func changeTapped(cell: ListCell)
}

class ListCell: UITableViewCell {
  
  var delegate: ListCellDelegate?
  
  func configCell(folder: Folder) {
    textLabel?.text = folder.name
  }
  
  func configCell(note: Note) {
    textLabel?.text = note.contents
  }
  
  @IBAction func changeButtonTapped(_ sender: Any) {
    delegate?.changeTapped(cell: self)
  }
}

