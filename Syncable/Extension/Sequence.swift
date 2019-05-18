//
//  Sequence.swift
//  Syncable
//
//  Created by junwoo on 21/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation
import CoreData

extension Sequence where Iterator.Element: NSManagedObject {
  
  func remap(to context: NSManagedObjectContext) -> [Iterator.Element] {
    return map { unmappedMO in
      guard unmappedMO.managedObjectContext !== context else { return unmappedMO }
      guard let object = context.object(with: unmappedMO.objectID)
        as? Iterator.Element else { fatalError("Invalid object type") }
      return object
    }
  }
  
  func filter(_ entityAndPredicate: EntityAndPredicate<Iterator.Element>) -> [Iterator.Element] {
    typealias MO = Iterator.Element
    let filtered = filter { (mo: Iterator.Element) -> Bool in
      guard mo.entity === entityAndPredicate.entity else { return false }
      return entityAndPredicate.predicate.evaluate(with: mo)
    }
    return Array(filtered)
  }
}

extension Sequence {
  func asyncForEach(completion: @escaping () -> (),
                    block: (Iterator.Element, @escaping () -> ()) -> ()) {
    let group = DispatchGroup()
    let innerCompletion = { group.leave() }
    for x in self {
      group.enter()
      block(x, innerCompletion)
    }
    group.notify(queue: DispatchQueue.main, execute: completion)
  }
}
