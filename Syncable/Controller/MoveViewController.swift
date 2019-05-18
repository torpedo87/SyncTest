//
//  MoveViewController.swift
//  Syncable
//
//  Created by junwoo on 11/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CoreData

class MoveViewController: UIViewController {
  
  @IBOutlet weak var tableView: UITableView!
  var coreDataStack: CoreDataStack!
  var selectedNotes: [Note]!
  var folders: [Folder]!
  var existingFolder: Folder!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
  }
  
  @IBAction func cancelButtonTapped(_ sender: Any) {
    dismiss(animated: true, completion: nil)
  }
  
  private func refresh() {
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Folder")
    let sort = NSSortDescriptor(key: #keyPath(Folder.modified), ascending: true)
    request.sortDescriptors = [sort]
    let deletedLocally = NSPredicate(format: "%K != NULL",
                                     LocalNote.markedForDeletionDateKey)
    let deletedRemotely = NSPredicate(format: "%K == true",
                                      LocalNote.markedForRemoteDeletionKey)
    let invisible = NSCompoundPredicate(orPredicateWithSubpredicates:
      [deletedLocally, deletedRemotely])
    request.predicate = NSCompoundPredicate(notPredicateWithSubpredicate: invisible)
    
    do {
      folders = try coreDataStack.managedContext.fetch(request) as? [Folder]
    } catch {
      print(error.localizedDescription)
    }
    
  }
}

extension MoveViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return folders.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "MoveCell", for: indexPath)
    cell.textLabel?.text = folders[indexPath.row].name
    return cell
  }
}

extension MoveViewController: UITableViewDelegate {
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    coreDataStack.managedContext.performChanges {
      let newFolder = self.folders[indexPath.row]
      self.selectedNotes.forEach {
        self.existingFolder.removeFromNotes($0)
        $0.folder = newFolder
        newFolder.addToNotes($0)
        $0.isUpdateNeeded = true
      }
    }
    dismiss(animated: true, completion: nil)
  }
}
