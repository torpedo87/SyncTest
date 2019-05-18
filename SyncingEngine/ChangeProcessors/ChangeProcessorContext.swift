//
//  ChangeProcessorContext.swift
//  Syncable
//
//  Created by junwoo on 23/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

protocol ChangeProcessorContext: class {
  
  var context: NSManagedObjectContext { get }
  var remote: CloudKitRemote { get }
  func perform(_ block: @escaping () -> ())
  func perform<A, B>(_ block: @escaping (A, B) -> ()) -> (A, B) -> ()
}
