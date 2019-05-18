//
//  NSError.swift
//  Syncable
//
//  Created by junwoo on 04/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CloudKit

enum RemoteError {
  case permanent([CKRecord.ID])
  case temporary
  
  var isPermanent: Bool {
    switch self {
    case .permanent: return true
    default: return false
    }
  }
}

extension RemoteError {
  init?(cloudKitError: Error?) {
    guard let error = cloudKitError.flatMap({ $0 as NSError }) else { return nil }
    if error.permanentCloudKitError {
      self = .permanent(error.partiallyFailedRecordIDsWithPermanentError.map { $0 })
    } else {
      self = .temporary
    }
  }
}

extension NSError {
  func partiallyFailedRecords() -> [CKRecord.ID:NSError] {
    guard domain == CKErrorDomain else { return [:] }
    let errorCode = CKError.Code(rawValue: code)
    guard errorCode == .partialFailure else { return [:] }
    return userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID:NSError] ?? [:]
  }
  var partiallyFailedRecordIDsWithPermanentError: [CKRecord.ID] {
    var result: [CKRecord.ID] = []
    for (remoteID, partialError) in partiallyFailedRecords() {
      if partialError.permanentCloudKitError {
        result.append(remoteID)
      }
    }
    return result
  }
  
  var permanentCloudKitError: Bool {
    guard domain == CKErrorDomain else { return false }
    guard let errorCode = CKError.Code(rawValue: code) else { return false }
    
    switch errorCode {
      //영구적 에러
    case .alreadyShared: return true
    case .assetFileNotFound: return true
    case .assetFileModified: return true
    case .badContainer: return true
    case .badDatabase: return true
    case .changeTokenExpired: return true
    case .constraintViolation: return true
    case .incompatibleVersion: return true
    case .internalError: return true
    case .invalidArguments: return true
    case .limitExceeded: return true
    case .managedAccountRestricted: return true
    case .missingEntitlement: return true
    case .notAuthenticated: return true
    case .participantMayNeedVerification: return true
    case .permissionFailure: return true
    case .unknownItem: return true
    case .userDeletedZone: return true
    case .zoneNotFound: return true
    case .serverRecordChanged: return true
    case .serverRejectedRequest: return true
    case .referenceViolation: return true
      
      //일시적 에러
    case .batchRequestFailed: return false
    case .networkFailure: return false
    case .networkUnavailable: return false
    case .operationCancelled: return false
    case .partialFailure: return false
    case .quotaExceeded: return false
    case .resultsTruncated: return false
    case .serviceUnavailable: return false
    case .requestRateLimited: return false
    case .zoneBusy: return false
    case .tooManyParticipants: return false
    case .serverResponseLost: return false
      
    default: return false
    }
  }
}
