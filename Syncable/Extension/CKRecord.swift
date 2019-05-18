//
//  CKRecord.swift
//  Syncable
//
//  Created by junwoo on 20/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

//record -> metadata
extension CKRecord {

  var metaData: Data {
    let data = NSMutableData()
    let coder = NSKeyedArchiver(forWritingWith: data)
    coder.requiresSecureCoding = true
    self.encodeSystemFields(with: coder)
    coder.finishEncoding()
    return Data(referencing: data)
  }
  
  func insert(into context: NSManagedObjectContext) {
    context.performChanges {
      
      if self.recordType == RemoteRecord.folder {
        let folder = Folder(entity: Folder.entity(), insertInto: context)
        folder.name = self[RemoteFolder.name] as? String
        folder.created = self[RemoteFolder.created] ?? self.creationDate
        folder.modified = self[RemoteFolder.modified] ?? self.modificationDate
        folder.metadata = self.metaData
        folder.isUpdateNeeded = false
        folder.remoteIdentifier = self.recordID.recordName
        folder.markedForRemoteDeletion = false
      } else {
        let note = Note(entity: Note.entity(), insertInto: context)
        note.contents = self[RemoteNote.contents] as? String
        note.created = self[RemoteNote.created] ?? self.creationDate
        note.modified = self[RemoteNote.modified] ?? self.modificationDate
        note.metadata = self.metaData
        note.isUpdateNeeded = false
        note.remoteIdentifier = self.recordID.recordName
        note.markedForRemoteDeletion = false
        let folderRef = self[RemoteNote.folder] as! CKRecord.Reference
        let folder = Folder.fetch(in: context) { request in
          request.predicate = Folder.predicateForRemoteIdentifiers([folderRef.recordID])
          request.returnsObjectsAsFaults = false
        }.first
        if let folder = folder {
          note.folder = folder
          folder.addToNotes(note)
        }
        if let assets = self[RemoteNote.photos] as? [CKAsset] {
          assets.forEach{
            let photo = Photo(entity: Photo.entity(), insertInto: context)
            photo.insertedAt = Date()
            photo.note = note
            do {
              photo.photoData = try Data(contentsOf: $0.fileURL!)
            } catch {
              print(error.localizedDescription)
            }
            note.addToPhotos(photo)
          }
        }
      }
      
    }
  }
}

//metadata -> record
extension NSData {
  var ckRecorded: CKRecord? {
    let coder = NSKeyedUnarchiver(forReadingWith: self as Data)
    coder.requiresSecureCoding = true
    let record = CKRecord(coder: coder)
    coder.finishDecoding()
    return record
  }
}

extension Data {
  var ckRecorded: CKRecord? {
    let coder = NSKeyedUnarchiver(forReadingWith: self as Data)
    coder.requiresSecureCoding = true
    let record = CKRecord(coder: coder)
    coder.finishDecoding()
    return record
  }
}

enum CloudKitRecordChange {
  case created(CKRecord)
  case updated(CKRecord)
  case deleted(CKRecord.ID)
}

extension CKDatabase {
  
  func fetchRecords(for changeReasons: [CKRecord.ID: CKQueryNotification.Reason], completion: @escaping ([CloudKitRecordChange], NSError?) -> ()) {
    var deletedIDs: [CKRecord.ID] = []
    var insertedOrUpdatedIDs: [CKRecord.ID] = []
    for (id, reason) in changeReasons {
      switch reason {
      case .recordDeleted: deletedIDs.append(id)
      default: insertedOrUpdatedIDs.append(id)
      }
    }
    let op = CKFetchRecordsOperation(recordIDs: insertedOrUpdatedIDs)
    op.fetchRecordsCompletionBlock = { recordsByID, error in
      var changes: [CloudKitRecordChange] = deletedIDs.map(CloudKitRecordChange.deleted)
      for (id, record) in recordsByID ?? [:] {
        guard let reason = changeReasons[id] else { continue }
        switch reason {
        case .recordCreated: changes.append(CloudKitRecordChange.created(record))
        case .recordUpdated: changes.append(CloudKitRecordChange.updated(record))
        default: fatalError("should not contain anything other than inserts and updates")
        }
      }
      completion(changes, error as NSError?)
    }
    add(op)
  }
  
}
