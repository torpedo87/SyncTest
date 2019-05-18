//
//  Note.swift
//  Syncable
//
//  Created by junwoo on 02/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

extension Note: CKRecordable {
  var remoteID: String? {
    return remoteIdentifier
  }
  
  func recordify() -> CKRecord {
    switch metadata {
    // update
    case .some(let data):
      let record = data.ckRecorded!
      record[RemoteNote.contents] = contents! as NSString
      record[RemoteNote.created] = created
      record[RemoteNote.modified] = modified
      record[RemoteNote.folder] = CKRecord.Reference(record: folder!.recordify(),
                                                     action: .deleteSelf)
      var assets = [CKAsset]()
      if let photoArr = Array(photos ?? []) as? [Photo] {
        photoArr.forEach{
          let fileUrl = $0.photoData!.temporaryURL!
          let asset = CKAsset(fileURL: fileUrl)
          assets.append(asset)
        }
      }
      record[RemoteNote.photos] = assets
      return record
      
    // create
    case .none:
      let recordID = CKRecord.ID(recordName: remoteIdentifier!,
                                 zoneID: CloudKitRemote.share.customZoneId)
      let record = CKRecord(recordType: RemoteRecord.note, recordID: recordID)
      record[RemoteNote.contents] = self.contents
      record[RemoteNote.created] = self.created
      record[RemoteNote.modified] = self.modified
      record[RemoteNote.folder] = CKRecord.Reference(record: folder!.recordify(),
                                                     action: .deleteSelf)
      var assets = [CKAsset]()
      if let photoArr = Array(photos ?? []) as? [Photo] {
        photoArr.forEach{
          let fileUrl = $0.photoData!.temporaryURL!
          let asset = CKAsset(fileURL: fileUrl)
          assets.append(asset)
        }
      }
      record[RemoteNote.photos] = assets
      return record
    }
  }
  
  static func fetch(in context: NSManagedObjectContext,
                    configurationBlock: (NSFetchRequest<Note>) -> () = { _ in }) -> [Note] {
    let request = NSFetchRequest<Note>.init(entityName: "Note")
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
      self.contents = String.randomString()
      self.modified = Date()
      let randomPhotoArray = [Array(1...5).randomElement()!, Array(1...5).randomElement()!, Array(1...5).randomElement()!]
        .map { "random\($0)" }
        .map { Photo.create(in: context, note: self, photoData: UIImage(named: $0)!.pngData()!) }
      
      self.photos = NSOrderedSet(array: randomPhotoArray)
      self.isUpdateNeeded = true
    }
  }
  
  static func addRandomly(in context: NSManagedObjectContext, folder: Folder) {
    let selectedImages = [UIImage(named: "twitter")!, UIImage(named: "instagram")!, UIImage(named: "facebook")!]
    
    context.performChanges {
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
  
  static func create(in context: NSManagedObjectContext, contents: String, folder: Folder) {
    context.performChanges {
      let note = Note(entity: Note.entity(), insertInto: context)
      note.remoteIdentifier = UUID().uuidString
      note.contents = contents
      note.created = Date()
      note.modified = Date()
      note.folder = folder
      folder.addToNotes(note)
      note.photos = []
    }
  }
}

extension Note: DelayedDeletable {
  
  static func predicateForRemoteIdentifiers(_ ids: [CKRecord.ID]) -> NSPredicate {
    return NSPredicate(format: "%K in %@", LocalNote.remoteIdentifierKey,
                       ids.map{ $0.recordName })
  }
}

