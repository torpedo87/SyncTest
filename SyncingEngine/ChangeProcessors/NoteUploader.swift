//
//  NoteUploader.swift
//  Syncable
//
//  Created by junwoo on 23/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData


class NoteUploader {
  
  var elementsInProgress = InProgressTracker<Note>()
  
  var predicateForLocallyTrackedElements: NSPredicate {
    let notUploaded = NSPredicate(format: "%K == NULL",
                                  LocalNote.checkUploadKey)
    let updateNeeded = NSPredicate(format: "%K == Yes",
                                   LocalNote.updateKey)
    return NSCompoundPredicate(orPredicateWithSubpredicates: [notUploaded, updateNeeded])
  }
}

extension NoteUploader: ChangeProcessor {
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               in context: ChangeProcessorContext,
                               completion: () -> ()) {
    completion()
  }
  
  func processChangedLocalObjects(_ objects: [NSManagedObject],
                                  in context: ChangeProcessorContext) {
    
    //아직 업로드 안된 애들만 필터링
    let matching = objects.filter(entityAndPredicateForLocallyTrackedObjects(in: context)!)
    let insertions = elementsInProgress.objectsToProcess(from: matching as! [Note])
    guard insertions.count > 0 else { return }
    
    context.remote.upload(insertions,
                          completion: context.perform { remoteNotes, error in
                            guard !(error?.isPermanent ?? false) else {
                              insertions.forEach { $0.markForLocalDeletion() }
                              self.elementsInProgress.markObjectsAsComplete(insertions)
                              return
                            }
                            for note in insertions {
                              
                              guard let remoteNote = remoteNotes.first(where: {
                                note.created == $0[RemoteNote.created] }) else { continue }
                              note.metadata = remoteNote.metaData
                              note.isUpdateNeeded = false
                              
                            }
                            context.context.saveOrRollback()
                            self.elementsInProgress.markObjectsAsComplete(insertions)
                            
    })
  }
  func entityAndPredicateForLocallyTrackedObjects(in context: ChangeProcessorContext) ->
    EntityAndPredicate<NSManagedObject>? {
    let predicate = predicateForLocallyTrackedElements
    return EntityAndPredicate(entity: Note.entity(), predicate: predicate)
  }
}

class EntityAndPredicate<A : NSManagedObject> {
  let entity: NSEntityDescription
  let predicate: NSPredicate
  
  init(entity: NSEntityDescription, predicate: NSPredicate) {
    self.entity = entity
    self.predicate = predicate
  }
}

extension EntityAndPredicate {
  var fetchRequest: NSFetchRequest<A> {
    let request = NSFetchRequest<A>()
    request.entity = entity
    request.predicate = predicate
    return request
  }
}
