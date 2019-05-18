//
//  Data.swift
//  Syncable
//
//  Created by junwoo on 09/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation

extension Data {
  var temporaryURL: URL? {
    do {
      let filename = "\(ProcessInfo.processInfo.globallyUniqueString)._file.bin"
      var url = URL(fileURLWithPath: NSTemporaryDirectory())
      url.appendPathComponent(filename)
      try self.write(to: url, options: .atomicWrite)
      return url
    } catch {
      return nil
    }
  }
}
