//
//  Constants.swift
//  Syncable
//
//  Created by junwoo on 16/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation

enum RemoteRecord {
  static let note = "Note"
  static let folder = "Folder"
}

enum RemoteNote {
  static let contents = "Contents"
  static let created = "Created"
  static let modified = "Modified"
  static let folder = "Folder"
  static let photos = "Photos"
}

enum RemoteFolder {
  static let name = "Name"
  static let created = "Created"
  static let modified = "Modified"
}

enum LocalNote {
  static let remoteIdentifierKey = "remoteIdentifier"
  static let checkUploadKey = "metadata"
  static let updateKey = "isUpdateNeeded"
  static let markedForDeletionDateKey = "markedForDeletionDate"
  static let markedForRemoteDeletionKey = "markedForRemoteDeletion"
}


