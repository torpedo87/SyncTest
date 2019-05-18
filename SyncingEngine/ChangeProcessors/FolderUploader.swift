//
//  FolderUploader.swift
//  Syncable
//
//  Created by junwoo on 09/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData


class FolderUploader {
  
  var elementsInProgress = InProgressTracker<Folder>()
  
  var predicateForLocallyTrackedElements: NSPredicate {
    let notUploaded = NSPredicate(format: "%K == NULL", LocalNote.checkUploadKey)
    let updateNeeded = NSPredicate(format: "%K == Yes", LocalNote.updateKey)
    return NSCompoundPredicate(orPredicateWithSubpredicates: [notUploaded, updateNeeded])
  }
}

extension FolderUploader: ChangeProcessor {
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               in context: ChangeProcessorContext, completion: () -> ()) {
    completion()
  }
  
  func processChangedLocalObjects(_ objects: [NSManagedObject],
                                  in context: ChangeProcessorContext) {
    
    //아직 업로드 안된 애들만 필터링
    let matching = objects.filter(entityAndPredicateForLocallyTrackedObjects(in: context)!)
    let insertions = elementsInProgress.objectsToProcess(from: matching as! [Folder])
    guard insertions.count > 0 else { return }
    
    context.remote.upload(insertions,
                          completion: context.perform { remoteFolders, error in
                            
                            guard !(error?.isPermanent ?? false) else {
                              insertions.forEach { $0.markForLocalDeletion() }
                              self.elementsInProgress.markObjectsAsComplete(insertions)
                              return
                            }
                            
                            for localFolder in insertions {
                              
                              guard let remoteFolder = remoteFolders.first(where: {
                                localFolder.created == $0[RemoteFolder.created] }) else { continue }
                              localFolder.metadata = remoteFolder.metaData
                              localFolder.isUpdateNeeded = false
                            }
                            context.context.saveOrRollback()
                            self.elementsInProgress.markObjectsAsComplete(insertions)
                            
    })
  }
  func entityAndPredicateForLocallyTrackedObjects(in context: ChangeProcessorContext) ->
    EntityAndPredicate<NSManagedObject>? {
    let predicate = predicateForLocallyTrackedElements
    return EntityAndPredicate(entity: Folder.entity(), predicate: predicate)
  }
}
