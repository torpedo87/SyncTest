//
//  ChangeProcessor.swift
//  Syncable
//
//  Created by junwoo on 25/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

protocol ChangeProcessor {
  
  func processChangedLocalObjects(_ objects: [NSManagedObject],
                                  in context: ChangeProcessorContext)
  func entityAndPredicateForLocallyTrackedObjects(in context: ChangeProcessorContext) ->
    EntityAndPredicate<NSManagedObject>?
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               in context: ChangeProcessorContext,
                               completion: () -> ())
}
