//
//  CKRecordable.swift
//  Syncable
//
//  Created by junwoo on 09/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CloudKit

protocol CKRecordable {
  var remoteID: String? { get }
  func recordify() -> CKRecord
}
