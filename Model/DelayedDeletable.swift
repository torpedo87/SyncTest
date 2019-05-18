//
//  DelayedDeletable.swift
//  Syncable
//
//  Created by junwoo on 27/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

protocol DelayedDeletable: class {
  var markedForDeletionDate: Date? { get set }
  func markForLocalDeletion()
}

extension DelayedDeletable where Self: NSManagedObject {
  
  func markForLocalDeletion() {
    guard isFault || markedForDeletionDate == nil else { return }
    markedForDeletionDate = Date()
  }
  
  static func batchDeleteObjectsMarkedForLocalDeletionInContext(_ managedObjectContext: NSManagedObjectContext) {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Note")
    fetchRequest.predicate = NSPredicate(format: "%K != NULL",
                                         LocalNote.markedForDeletionDateKey)
    let batchRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    batchRequest.resultType = .resultTypeStatusOnly
    try! managedObjectContext.execute(batchRequest)
  }
}

