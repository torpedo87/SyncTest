//
//  Photo.swift
//  Syncable
//
//  Created by junwoo on 16/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

extension Photo {
  
  static func create(in context: NSManagedObjectContext, note: Note, photoData: Data) -> Photo {
    let photo = Photo(entity: Photo.entity(), insertInto: context)
    photo.insertedAt = Date()
    photo.note = note
    photo.photoData = photoData
    return photo
  }
}
