//
//  Note+CoreDataProperties.swift
//  Syncable
//
//  Created by junwoo on 20/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//
//

import Foundation
import CoreData


extension Note {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var contents: String
    @NSManaged public var created: NSDate
    @NSManaged public var modified: NSDate
    @NSManaged public var metadata: NSData

}
