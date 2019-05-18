//
//  InProgressTracker.swift
//  Syncable
//
//  Created by junwoo on 15/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

class InProgressTracker<O: NSManagedObject> {
  
  var objectsInProgress = Set<O>()
  
  init() {}
  
  func objectsToProcess(from objects: [O]) -> [O] {
    let added = objects.filter { !objectsInProgress.contains($0) }
    objectsInProgress.formUnion(added)
    return added
  }
  
  func markObjectsAsComplete(_ objects: [O]) {
    objectsInProgress.subtract(objects)
  }
}
