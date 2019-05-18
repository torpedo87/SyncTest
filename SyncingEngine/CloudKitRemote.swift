//
//  CloudKitRemote.swift
//  Syncable
//
//  Created by junwoo on 17/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CloudKit

enum RemoteRecordChange<T: CKRecord> {
  case changed(T)
  case deleted(T.ID)
}

class CloudKitRemote {
  
  static let share = CloudKitRemote()
  let customZoneId = CKRecordZone.ID(zoneName: "Note", ownerName: CKCurrentUserDefaultName)
  let privateSubscriptionId = "private-changes"
  var container: CKContainer
  var privateDB: CKDatabase
  
  private init() {
    container = CKContainer.default()
    privateDB = container.privateCloudDatabase
  }

  func createDatabaseSubscriptionOperation(subscriptionId: String) -> CKModifySubscriptionsOperation {
    
    let subscription = CKDatabaseSubscription(subscriptionID: subscriptionId)
    let info = CKSubscription.NotificationInfo()
    info.shouldSendContentAvailable = true
    subscription.notificationInfo = info
    let operation = CKModifySubscriptionsOperation(
      subscriptionsToSave: [subscription],
      subscriptionIDsToDelete: nil
    )
    return operation
  }
  
  func upload(_ objects: [CKRecordable],
              completion: @escaping ([CKRecord], RemoteError?) -> ()) {
    let recordsToSave = objects.compactMap{ $0.recordify() }
    let op = CKModifyRecordsOperation(recordsToSave: recordsToSave,
                                      recordIDsToDelete: nil)
    op.qualityOfService = .userInitiated
    op.modifyRecordsCompletionBlock = { modifiedRecords, _, error in
      
      let remoteError = RemoteError(cloudKitError: error)
      completion(modifiedRecords ?? [], remoteError)
    }
    
    op.perRecordCompletionBlock = { record, error in
      if error != nil {
        self.handleErrorWhenSave(record: record, error: error!)
      }
    }
    privateDB.add(op)
  }
  
  private func handleErrorWhenSave(record: CKRecord, error: Error) {
    let errorInfo = error as NSError
    if errorInfo.code == CKError.serverRecordChanged.rawValue {
      let errorDict: [AnyHashable: Any] = errorInfo.userInfo
      let info = errorDict as NSDictionary
      let clientRecord = info[CKRecordChangedErrorClientRecordKey] as! CKRecord
      let serverRecord = info[CKRecordChangedErrorServerRecordKey] as! CKRecord
      //let localRecord = info[CKRecordChangedErrorAncestorRecordKey] as! CKRecord
      serverRecord[RemoteNote.contents] = clientRecord[RemoteNote.contents]
      serverRecord[RemoteNote.contents] = clientRecord[RemoteNote.modified]
      self.privateDB.save(serverRecord, completionHandler: { (record, error) in
        if error != nil {
          print(error!.localizedDescription)
        }
      })
    }
  }
  
  func remove(_ objects: [CKRecordable],
              completion: @escaping ([String], RemoteError?) -> ()) {
    let recordIDsToDelete = objects.map { (object: CKRecordable) -> CKRecord.ID in
      guard let name = object.remoteID else { fatalError("Must have a remote ID") }
      return CKRecord.ID(recordName: name, zoneID: customZoneId)
    }
    let op = CKModifyRecordsOperation(recordsToSave: nil,
                                      recordIDsToDelete: recordIDsToDelete)
    op.qualityOfService = .userInitiated
    op.modifyRecordsCompletionBlock = { _, deletedRecordIDs, error in
      
      let remoteError = RemoteError(cloudKitError: error)
      completion((deletedRecordIDs ?? []).map { $0.recordName }, remoteError)
    }
    op.perRecordCompletionBlock = { record, error in
      if error != nil {
        print(error!.localizedDescription)
      }
    }
    privateDB.add(op)
  }
  
  func fetchChanges(completion: @escaping ([RemoteRecordChange<CKRecord>]) -> Void) {
    fetchDatabaseChanges(database: self.privateDB, databaseTokenKey: "private",
                         completion: completion)
  }
  
  //update 된 zone id 받기
  func fetchDatabaseChanges(database: CKDatabase, databaseTokenKey: String, completion: @escaping ([RemoteRecordChange<CKRecord>]) -> Void) {
    
    var changedZoneIDs: [CKRecordZone.ID] = []
    let changeToken = UserDefaults.standard.getServerChangedToken(key: databaseTokenKey)
    let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
    
    operation.recordZoneWithIDChangedBlock = { (zoneID) in
      changedZoneIDs.append(zoneID)
    }
    
    operation.changeTokenUpdatedBlock = { (token) in
      UserDefaults.standard.setServerChangedToken(key: databaseTokenKey, token: token)
    }
    
    operation.fetchDatabaseChangesCompletionBlock = { (token, moreComing, error) in
      if error != nil {
        print(error!.localizedDescription)
      }
      UserDefaults.standard.setServerChangedToken(key: databaseTokenKey, token: token)
      guard changedZoneIDs.count > 0 else { return }
      self.fetchZoneChanges(database: database, databaseTokenKey: databaseTokenKey,
                            zoneIDs: changedZoneIDs) { remoteRecordChange in
        completion(remoteRecordChange)
      }
    }
    
    operation.qualityOfService = .userInitiated
    database.add(operation)
  }
  
  func fetchZoneChanges(database: CKDatabase, databaseTokenKey: String,
                        zoneIDs: [CKRecordZone.ID],
                        completion: @escaping ([RemoteRecordChange<CKRecord>]) -> Void) {
    
    var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneOptions]()
    var deletedRecordIds = [RemoteRecordChange]()
    var changedRecords = [RemoteRecordChange]()
    
    for zoneID in zoneIDs {
      let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
      options.previousServerChangeToken = UserDefaults.standard.getServerChangedToken(key: "\(databaseTokenKey)/\(zoneID.zoneName)")
        optionsByRecordZoneID[zoneID] = options
    }
    let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIDs,
                                                      optionsByRecordZoneID: optionsByRecordZoneID)

    operation.recordChangedBlock = { (record) in
      changedRecords.append(RemoteRecordChange.changed(record))
    }
    operation.recordWithIDWasDeletedBlock = { recordId, _ in
      deletedRecordIds.append(RemoteRecordChange.deleted(recordId))
    }
    
    operation.recordZoneChangeTokensUpdatedBlock = { (zoneId, token, data) in
      UserDefaults.standard.setServerChangedToken(key: "\(databaseTokenKey)/\(zoneId.zoneName)",
        token: token)
    }
    
    operation.recordZoneFetchCompletionBlock = { (zoneId, changeToken, _, _, error) in
      if error != nil {
        print(error!.localizedDescription)
      }
      UserDefaults.standard.setServerChangedToken(key: "\(databaseTokenKey)/\(zoneId.zoneName)",
        token: changeToken)
    }
    
    operation.fetchRecordZoneChangesCompletionBlock = { (error) in
      if error != nil {
        print("Error fetching zone changes for \(databaseTokenKey) database:", error!)
      }
      completion(changedRecords + deletedRecordIds)
    }
    
    database.add(operation)
  }
}
