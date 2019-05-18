//
//  String.swift
//  Syncable
//
//  Created by junwoo on 14/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import Foundation

extension String {
  
  static func randomString() -> String {
    
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let len = UInt32(letters.length)
    
    var randomString = ""
    let length = 50
    for _ in 0 ..< length {
      let rand = arc4random_uniform(len)
      var nextChar = letters.character(at: Int(rand))
      randomString += NSString(characters: &nextChar, length: 1) as String
    }
    
    return String(randomString)
  }
}
