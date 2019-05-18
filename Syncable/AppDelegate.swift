//
//  AppDelegate.swift
//  Syncable
//
//  Created by junwoo on 13/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CoreData
import UserNotifications
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  lazy var coreDataStack = CoreDataStack(modelName: "Syncable")
  var syncCoordinator: SyncCoordinator!

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    

    application.registerForRemoteNotifications()
    
    guard let navigationController = window?.rootViewController as? UINavigationController,
      let foldersViewController = navigationController.topViewController as? FoldersViewController else {
        return true
    }
    
    foldersViewController.coreDataStack = coreDataStack
    syncCoordinator = SyncCoordinator(container: coreDataStack.storeContainer)
    
    //create zone
    let createZoneGroup = DispatchGroup()
    if !UserDefaults.standard.isZoneCreated() {
      createZoneGroup.enter()
      
      let customZone = CKRecordZone(zoneID: CloudKitRemote.share.customZoneId)
      let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone],
                                                             recordZoneIDsToDelete: [] )
      createZoneOperation.modifyRecordZonesCompletionBlock = { (saved, deleted, error) in
        if error != nil {
          print("create zone error : \(error!.localizedDescription)")
        } else {
          UserDefaults.standard.setZone(bool: true)
        }
        createZoneGroup.leave()
      }
      createZoneOperation.qualityOfService = .userInitiated
      CloudKitRemote.share.privateDB.add(createZoneOperation)
    } else {
      print("zone exist")
    }
    
    //create subscription
    if !UserDefaults.standard.isSubscriptionCreated() {
      let createSubscriptionOperation = CloudKitRemote.share.createDatabaseSubscriptionOperation(subscriptionId: CloudKitRemote.share.privateSubscriptionId)
      
      createSubscriptionOperation.modifySubscriptionsCompletionBlock = { (subscriptions, deletedIds, error) in
        if error != nil {
          print("create subscription error : \(error!.localizedDescription)")
        } else {
          UserDefaults.standard.setSubscription(bool: true)
        }
      }
      CloudKitRemote.share.privateDB.add(createSubscriptionOperation)
    } else {
      print("subscription exist")
    }
    
    syncCoordinator.remote.fetchChanges() { remoteRecordChanges in
      
      self.syncCoordinator.processRemoteChanges(remoteRecordChanges, completion: {
        
      })
    }
    
    return true
  }
  
  
  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("recieved noti")
    let dict = userInfo as! [String: NSObject]
    if let _ = CKNotification(fromRemoteNotificationDictionary:dict) as? CKDatabaseNotification {
      syncCoordinator.remote.fetchChanges() { remoteRecordChanges in
        self.syncCoordinator.processRemoteChanges(remoteRecordChanges, completion: {
          completionHandler(.newData)
        })
      }
    }
  }
  
  func applicationDidEnterBackground(_ application: UIApplication) {
    //노트 삭제
    let persistentContainer = coreDataStack.storeContainer
    persistentContainer.viewContext.batchDeleteObjectsMarkedForLocalDeletion()
    persistentContainer.viewContext.refreshAllObjects()
  }
}
