//
//  ForTest.swift
//  Syncable
//
//  Created by junwoo on 15/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

class ForTest {
  
  static func checkCount(in context: NSManagedObjectContext, entity: String) {
    let fetchRequest = NSFetchRequest<Note>(entityName: entity)
    let count = try! context.count(for: fetchRequest)
    print(count)
  }
}
