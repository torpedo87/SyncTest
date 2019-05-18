//
//  NSManagedObjectContext.swift
//  Syncable
//
//  Created by junwoo on 20/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
  
  @discardableResult
  func saveOrRollback() -> Bool {
    do {
      try save()
      return true
    } catch {
      rollback()
      print(error.localizedDescription)
      return false
    }
  }
  
  func performChanges(block: @escaping () -> ()) {
    perform {
      block()
      _ = self.saveOrRollback()
    }
  }
  
  func addContextDidSaveNotificationObserver(_ handler: @escaping (Notification) -> ()) {
    let nc = NotificationCenter.default
    nc.addObserver(forName: .NSManagedObjectContextDidSave,
                   object: self, queue: nil) { noti in
      handler(noti)
    }
  }
  
  func performMergeChanges(from noti: Notification) {
    perform {
      self.mergeChanges(fromContextDidSave: noti)
    }
  }
  
  func perform(group: DispatchGroup, block: @escaping () -> ()) {
    group.enter()
    perform {
      block()
      group.leave()
    }
  }
  
  func batchDeleteObjectsMarkedForLocalDeletion() {
    Folder.batchDeleteObjectsMarkedForLocalDeletionInContext(self)
    Note.batchDeleteObjectsMarkedForLocalDeletionInContext(self)
  }
  
}
