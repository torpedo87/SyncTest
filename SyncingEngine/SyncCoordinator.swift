//
//  SyncCoordinator.swift
//  Syncable
//
//  Created by junwoo on 17/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CoreData
import Reachability

class SyncCoordinator {
  
  let viewContext: NSManagedObjectContext
  let syncContext: NSManagedObjectContext
  let syncGroup: DispatchGroup = DispatchGroup()
  let remote: CloudKitRemote
  let changeProcessors: [ChangeProcessor]
  let reachability = Reachability()!
  
  public init(container: NSPersistentContainer) {
    remote = CloudKitRemote.share
    viewContext = container.viewContext
    syncContext = container.newBackgroundContext()
    syncContext.name = "SyncCoordinator"
    syncContext.mergePolicy = NSMergePolicy(merge: .overwriteMergePolicyType)
    viewContext.mergePolicy = NSMergePolicy(merge: .overwriteMergePolicyType)
    changeProcessors = [NoteUploader(), FolderUploader(), Downloader(),
                        FolderRemover(), NoteRemover()]
    
    setup()
  }
  
  deinit {
    reachability.stopNotifier()
    NotificationCenter.default.removeObserver(self, name: .reachabilityChanged,
                                              object: reachability)
  }
  
  func setup() {
    self.perform {
      self.setReachabilityNotifier()
      self.setupContextNotificationObserving()
    }
  }
  
  func setReachabilityNotifier() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reachabilityChanged(note:)),
                                           name: .reachabilityChanged,
                                           object: reachability)
    
    do {
      try reachability.startNotifier()
    } catch {
      print("cannot start connection noti")
    }
  }
  
  func setupContextNotificationObserving() {
    viewContext.addContextDidSaveNotificationObserver { [weak self] noti in
      guard let self = self else { return }
      self.syncContext.performMergeChanges(from: noti)
      self.notifyAboutChangedObjects(from: noti)
    }
    
    syncContext.addContextDidSaveNotificationObserver { [weak self] noti in
      guard let self = self else { return }
      self.viewContext.performMergeChanges(from: noti)
      self.notifyAboutChangedObjects(from: noti)
    }
  }
  
  func notifyAboutChangedObjects(from notification: Notification) {
    syncContext.perform(group: syncGroup) {
      let updatedObjects = self.iterator(notification: notification,
                                         forKey: NSUpdatedObjectsKey)
      let insertedObjects = self.iterator(notification: notification,
                                          forKey: NSInsertedObjectsKey)
      
      //context swithching with objectID
      let updates = updatedObjects.remap(to: self.syncContext)
      let inserts = insertedObjects.remap(to: self.syncContext)
      
      guard (updates + inserts).count > 0 else { return }
      for cp in self.changeProcessors {
        cp.processChangedLocalObjects(updates + inserts, in: self)
      }
    }
  }
  
  private func iterator(notification: Notification, forKey key: String) ->
    AnyIterator<NSManagedObject> {
    guard let set = notification.userInfo?[key] as? NSSet else {
      return AnyIterator { nil }
    }
    var innerIterator = set.makeIterator()
    return AnyIterator { return innerIterator.next() as? NSManagedObject }
  }
  
  func processRemoteChanges<T>(_ changes: [RemoteRecordChange<T>],
                               completion: @escaping () -> ()) {
    
    
    changeProcessors.asyncForEach(completion: completion) { (changeProcessor, innerCompletion) in
      perform {
        changeProcessor.processRemoteChanges(changes, in: self,
                                             completion: innerCompletion)
      }
    }
    
  }
  
  @objc func reachabilityChanged(note: Notification) {
    let reachability = note.object as! Reachability
    switch reachability.connection {
    case .none: print("no network connection")
    case .cellular:
      fetchLocallyTrackedObjects()
      print("cellular")
    case .wifi:
      fetchLocallyTrackedObjects()
      print("wifi")
    }
  }
  
  func fetchLocallyTrackedObjects() {
    self.perform {
      var objects: Set<NSManagedObject> = []
      for cp in self.changeProcessors {
        guard let entityAndPredicate =
          cp.entityAndPredicateForLocallyTrackedObjects(in: self) else { continue }
        let request = entityAndPredicate.fetchRequest
        request.returnsObjectsAsFaults = false
        let result = try! self.syncContext.fetch(request)
        objects.formUnion(result)
        cp.processChangedLocalObjects(Array(objects), in: self)
      }
    }
  }
}

extension SyncCoordinator: ChangeProcessorContext {
  
  var context: NSManagedObjectContext {
    return syncContext
  }
  
  func perform(_ block: @escaping () -> ()) {
    syncContext.perform(group: syncGroup, block: block)
  }
  
  func perform<A,B>(_ block: @escaping (A,B) -> ()) -> (A,B) -> () {
    return { (a: A, b: B) -> () in
      self.perform {
        block(a, b)
      }
    }
  }
}
