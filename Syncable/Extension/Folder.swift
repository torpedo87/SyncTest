//
//  Folder.swift
//  Syncable
//
//  Created by junwoo on 09/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

extension Folder {
  static func fetch(in context: NSManagedObjectContext,
                    configurationBlock: (NSFetchRequest<Folder>) -> () = { _ in }) -> [Folder] {
    let request = NSFetchRequest<Folder>.init(entityName: "Folder")
    configurationBlock(request)
    do {
      return try context.fetch(request)
    } catch {
      print("fetch error")
      return []
    }
  }
  
  func randomChange(in context: NSManagedObjectContext) {
    context.performChanges {
      self.name = String.randomString()
      self.modified = Date()
      if let notes = self.notes, let noteArray = Array(notes) as? [Note] {
        noteArray.forEach {
          $0.contents = String.randomString()
          $0.isUpdateNeeded = true
        }
      }
      self.isUpdateNeeded = true
    }
  }
  
  static func create(in context: NSManagedObjectContext, name: String) {
    context.performChanges {
      let folder = Folder(entity: Folder.entity(), insertInto: context)
      folder.remoteIdentifier = UUID().uuidString
      folder.name = name
      folder.created = Date()
      folder.modified = Date()
      folder.notes = []
    }
  }
  
  static func addRandomly(in context: NSManagedObjectContext) {
    let selectedImages = [UIImage(named: "twitter")!, UIImage(named: "instagram")!, UIImage(named: "facebook")!]
    
    context.performChanges {
      let folder = Folder(entity: Folder.entity(), insertInto: context)
      folder.name = "test folder"
      folder.created = Date()
      folder.modified = Date()
      folder.remoteIdentifier = UUID().uuidString
      
      for _ in 1...50 {
        let note = Note(entity: Note.entity(), insertInto: context)
        note.contents = String.randomString()
        note.created = Date()
        note.modified = Date()
        note.remoteIdentifier = UUID().uuidString
        note.folder = folder
        folder.addToNotes(note)
        
        selectedImages.forEach {
          let imgData = $0.pngData()
          let photo = Photo(entity: Photo.entity(),
                            insertInto: context)
          photo.photoData = imgData
          photo.insertedAt = Date()
          photo.note = note
          note.addToPhotos(photo)
        }
      }
    }
    
  }
}

extension Folder: CKRecordable {
  var remoteID: String? {
    return remoteIdentifier
  }
  
  func recordify() -> CKRecord {
    
    switch metadata {
    // update
    case .some(let data):
      let record = data.ckRecorded!
      record[RemoteFolder.name] = self.name
      record[RemoteFolder.created] = created
      record[RemoteFolder.modified] = modified
      return record
      
    // create
    case .none:
      let recordID = CKRecord.ID(recordName: remoteIdentifier!,
                                 zoneID: CloudKitRemote.share.customZoneId)
      let record = CKRecord(recordType: RemoteRecord.folder, recordID: recordID)
      record[RemoteFolder.name] = self.name
      record[RemoteFolder.created] = created
      record[RemoteFolder.modified] = modified
      return record
    }
  }
}

extension Folder: DelayedDeletable {
  
  static func predicateForRemoteIdentifiers(_ ids: [CKRecord.ID]) -> NSPredicate {
    return NSPredicate(format: "%K in %@",
                       LocalNote.remoteIdentifierKey, ids.map{ $0.recordName })
  }
}
