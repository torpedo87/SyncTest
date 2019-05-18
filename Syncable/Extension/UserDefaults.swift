//
//  UserDefaults.swift
//  Syncable
//
//  Created by junwoo on 20/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CloudKit

extension UserDefaults {
  
  func setZone(bool: Bool) {
    self.set(bool, forKey: "createdCustomZone")
  }
  
  func setSubscription(bool: Bool) {
    self.set(bool, forKey: "subscribedToPrivateChanges")
  }
  
  func isZoneCreated() -> Bool {
    if let boolValue = self.value(forKey: "createdCustomZone") as? Bool {
      return boolValue
    } else {
      return false
    }
  }
  
  func isSubscriptionCreated() -> Bool {
    if let boolValue = self.value(forKey: "subscribedToPrivateChanges") as? Bool {
      return boolValue
    } else {
      return false
    }
  }
  
  func getServerChangedToken(key: String) -> CKServerChangeToken? {
    if let data = data(forKey: key),
      let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken {
      return token
    }
    return nil
  }
  
  func setServerChangedToken(key: String, token: CKServerChangeToken?) {
    guard let token = token else { return }
    let data = NSKeyedArchiver.archivedData(withRootObject: token)
    set(data, forKey: key)
  }
}
