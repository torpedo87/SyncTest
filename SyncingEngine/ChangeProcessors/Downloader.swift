//
//  Downloader.swift
//  Syncable
//
//  Created by junwoo on 10/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

class Downloader: ChangeProcessor {
  
  func processChangedLocalObjects(_ objects: [NSManagedObject],
                                  in context: ChangeProcessorContext) {
    
  }
  
  func entityAndPredicateForLocallyTrackedObjects(in context: ChangeProcessorContext) ->
    EntityAndPredicate<NSManagedObject>? {
    return nil
  }
  
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               in context: ChangeProcessorContext,
                               completion: () -> ()) {
    var changedRecords: [CKRecord] = []
    var deletionIDs: [CKRecord.ID] = []
    for change in changes {
      switch change {
      case .changed(let record): changedRecords.append(record)
      case .deleted(let id): deletionIDs.append(id)
      }
    }
    
    insertOrUpdate(changedRecords, into: context.context)
    deleteObjects(with: deletionIDs, in: context.context)
    completion()
  }
  
  
  private func insertOrUpdate(_ remoteRecords: [CKRecord],
                              into context: NSManagedObjectContext) {
    
    guard !remoteRecords.isEmpty else { return }
    var existingFolders = [String:Folder]()
    var existingNotes = [String:Note]()
    
    let changedRemoteFolderRecords = remoteRecords.filter {
      $0.recordType == RemoteRecord.folder }
    let folderIds = changedRemoteFolderRecords.map { $0.recordID }.compactMap { $0 }
    let folders = Folder.fetch(in: context) { request in
      request.predicate = Folder.predicateForRemoteIdentifiers(folderIds)
      request.returnsObjectsAsFaults = false
    }
    for folder in folders {
      existingFolders[folder.remoteIdentifier!] = folder
    }
    
    let changedRemoteNoteRecords = remoteRecords.filter {
      $0.recordType == RemoteRecord.note }
    let noteIds = changedRemoteNoteRecords.map { $0.recordID }.compactMap { $0 }
    let notes = Note.fetch(in: context) { request in
      request.predicate = Folder.predicateForRemoteIdentifiers(noteIds)
      request.returnsObjectsAsFaults = false
    }
    for note in notes {
      existingNotes[note.remoteIdentifier!] = note
    }
    
    
    for remoteRecord in remoteRecords {
      let id = remoteRecord.recordID.recordName
      //폴더
      if remoteRecord.recordType == RemoteRecord.folder {
        if let existingFolder = existingFolders[id] {
          existingFolder.created = remoteRecord[RemoteFolder.created] ?? remoteRecord.creationDate
          existingFolder.modified = remoteRecord[RemoteFolder.modified] ?? remoteRecord.modificationDate
          existingFolder.name = remoteRecord[RemoteFolder.name] ?? "folder name"
          existingFolder.metadata = remoteRecord.metaData
          context.saveOrRollback()
        } else {
          remoteRecord.insert(into: context)
        }
      }
        //노트
      else {
        if let existingNote = existingNotes[id] {
          existingNote.contents = remoteRecord[RemoteNote.contents] ?? ""
          existingNote.metadata = remoteRecord.metaData
          existingNote.created = remoteRecord[RemoteNote.created] ?? remoteRecord.creationDate
          existingNote.modified = remoteRecord[RemoteNote.modified] ?? remoteRecord.modificationDate
          let folderRef = remoteRecord[RemoteNote.folder] as! CKRecord.Reference
          let folderId = folderRef.recordID
          let folder = Folder.fetch(in: context) { request in
            request.predicate = Folder.predicateForRemoteIdentifiers([folderId])
            request.returnsObjectsAsFaults = false
            }.first!
          existingNote.folder = folder
          folder.addToNotes(existingNote)
          context.saveOrRollback()
        } else {
          remoteRecord.insert(into: context)
        }
      }
      
    }
    
  }
  
  private func deleteObjects(with ids: [CKRecord.ID], in context: NSManagedObjectContext) {
    guard !ids.isEmpty else { return }
    let notes = Note.fetch(in: context) { (request) -> () in
      request.predicate = Note.predicateForRemoteIdentifiers(ids)
      request.returnsObjectsAsFaults = false
    }
    let folders = Folder.fetch(in: context) { (request) -> () in
      request.predicate = Note.predicateForRemoteIdentifiers(ids)
      request.returnsObjectsAsFaults = false
    }
    context.performChanges {
      notes.forEach {
        $0.markForLocalDeletion()
        $0.markedForRemoteDeletion = true
      }
      folders.forEach {
        $0.markForLocalDeletion()
        $0.markedForRemoteDeletion = true
      }
    }
  }
}


