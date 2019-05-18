//
//  NoteRemover.swift
//  Syncable
//
//  Created by junwoo on 25/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

class NoteRemover: ChangeProcessor {
  
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               in context: ChangeProcessorContext, completion: () -> ()) {
    completion()
  }
  
  var elementsInProgress = InProgressTracker<Note>()
  
  var predicateForLocallyTrackedElements: NSPredicate {
    
    let marked = NSPredicate(format: "%K == true", LocalNote.markedForRemoteDeletionKey)
    let notDeleted = NSPredicate(format: "%K == NULL", LocalNote.markedForDeletionDateKey)
    return NSCompoundPredicate(andPredicateWithSubpredicates:[marked, notDeleted])
  }
  
  func processChangedLocalObjects(_ objects: [NSManagedObject],
                                  in context: ChangeProcessorContext) {
    
    let matching = objects.filter(entityAndPredicateForLocallyTrackedObjects(in: context)!)
    guard matching.count > 0 else { return }
    let deletableElements = elementsInProgress.objectsToProcess(from: matching as! [Note])
    let allDeletableObjects = Set(deletableElements)
    
    //클라우드는 지우고 로컬에만 남아있는 노트
    let localOnly = allDeletableObjects.filter { $0.remoteIdentifier == nil }
    //서버에도 아직 남아있는 노트들
    let objectsToDeleteRemotely = allDeletableObjects.subtracting(localOnly)
    
    deleteLocally(localOnly, context: context)
    deleteRemotely(objectsToDeleteRemotely, context: context)
  }
  
  private func deleteLocally(_ deletions: Set<Note>, context: ChangeProcessorContext) {
    deletions.forEach{ $0.markForLocalDeletion() }
  }
  
  
  private func deleteRemotely(_ deletions: Set<Note>, context: ChangeProcessorContext) {
    context.remote.remove(Array(deletions), completion:
      
      context.perform { [weak self] deletedRecordIDs, error in
        guard let self = self else { return }
        var deletedIDs = Set(deletedRecordIDs)
                            
        if error != nil {
          if case .permanent(let ids)? = error {
            deletedIDs.formUnion(ids.map{ $0.recordName })
          }
          
        } else {
          //클라우드에서 삭제된 노트
          let toBeDeleted = deletions.filter { deletedIDs.contains($0.remoteIdentifier ?? "") }
          self.deleteLocally(toBeDeleted, context: context)
          
          context.context.saveOrRollback()
          self.elementsInProgress.markObjectsAsComplete(Array(deletions))
        }
    })
  }
  
  func entityAndPredicateForLocallyTrackedObjects(in context: ChangeProcessorContext) ->
    EntityAndPredicate<NSManagedObject>? {
    let predicate = predicateForLocallyTrackedElements
    return EntityAndPredicate(entity: Note.entity(), predicate: predicate)
  }
}
