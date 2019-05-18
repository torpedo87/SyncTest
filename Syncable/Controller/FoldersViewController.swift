//
//  FoldersViewController.swift
//  Syncable
//
//  Created by junwoo on 07/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CoreData

class FoldersViewController: UIViewController {
  
  
  @IBOutlet weak var tableView: UITableView!
  var coreDataStack: CoreDataStack!
  private var fetchedRC: NSFetchedResultsController<Folder>!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Folders"
    tableView.register(UINib(nibName: "ListCell", bundle: nil), forCellReuseIdentifier: "ListCell")
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
    clearSelectedCell()
  }
  
  func clearSelectedCell() {
    if let selecteds = tableView.indexPathsForSelectedRows {
      selecteds.forEach {
        tableView.deselectRow(at: $0, animated: false)
      }
    }
  }
  
  private func refresh() {
    let request = Folder.fetchRequest() as NSFetchRequest<Folder>
    let sort = NSSortDescriptor(key: #keyPath(Folder.modified), ascending: true)
    request.sortDescriptors = [sort]
    
    //삭제 시 화면에 보이지 않도록
    let deletedLocally = NSPredicate(format: "%K != NULL",
                                     LocalNote.markedForDeletionDateKey)
    let deletedRemotely = NSPredicate(format: "%K == true",
                                      LocalNote.markedForRemoteDeletionKey)
    let invisible = NSCompoundPredicate(orPredicateWithSubpredicates:
      [deletedLocally, deletedRemotely])
    request.predicate = NSCompoundPredicate(notPredicateWithSubpredicate: invisible)
    
    do {
      fetchedRC = NSFetchedResultsController(fetchRequest: request,
                                             managedObjectContext: coreDataStack.managedContext,
                                             sectionNameKeyPath: nil,
                                             cacheName: nil)
      fetchedRC.delegate = self
      try fetchedRC.performFetch()
    } catch let error as NSError {
      print("cannot fetch : \(error), \(error.userInfo)")
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let vc = segue.destination as? NotesViewController,
      let path = tableView.indexPathForSelectedRow {
      vc.coreDataStack = coreDataStack
      vc.folder = fetchedRC.object(at: path)
    }
  }
  
  @IBAction func testButtonTapped(_ sender: Any) {
    Folder.addRandomly(in: coreDataStack.managedContext)
  }
  
  @IBAction func editButtonTapped(_ sender: Any) {
    tableView.setEditing(!tableView.isEditing, animated: true)
  }
  
  
  @IBAction func addButtonTapped(_ sender: Any) {
    let alert = UIAlertController(title: "new folder",
                                  message: "please write",
                                  preferredStyle: .alert)
    alert.addTextField(configurationHandler: nil)
    let cancel = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
    let save = UIAlertAction(title: "save", style: .default) { [weak self] _ in
      guard let self = self else { return }
      guard let txtField = alert.textFields?[0] else { return }
      guard let name = txtField.text else { return }
      guard !name.isEmpty else { return }
      self.createNewFolder(name: name)
    }
    alert.addAction(cancel)
    alert.addAction(save)
    present(alert, animated: true, completion: nil)
  }
  
  func createNewFolder(name: String) {
    Folder.create(in: coreDataStack.managedContext, name: name)
  }
  
  func renameFolder(folder: Folder, newName: String) {
    let context = coreDataStack.managedContext
    context.performChanges {
      folder.name = newName
      folder.modified = Date()
      folder.isUpdateNeeded = true
    }
  }
  
}

extension FoldersViewController: UITableViewDataSource {
  
  func tableView(_ tableView: UITableView,
                 numberOfRowsInSection section: Int) -> Int {
    guard let folders = fetchedRC.fetchedObjects else { return 0 }
    return folders.count
  }
  
  func tableView(_ tableView: UITableView,
                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell",
                                                for: indexPath) as? ListCell {
      let folder = fetchedRC.object(at: indexPath)
      cell.delegate = self
      cell.configCell(folder: folder)
      return cell
    }
    
    return UITableViewCell()
  }
  
}

extension FoldersViewController: ListCellDelegate {
  func changeTapped(cell: ListCell) {
    guard let indexPath = tableView.indexPath(for: cell) else { return }
    let folder = fetchedRC.object(at: indexPath)
    folder.randomChange(in: coreDataStack.managedContext)
  }
}

extension FoldersViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView,
                 commit editingStyle: UITableViewCell.EditingStyle,
                 forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let folder = fetchedRC.object(at: indexPath)
      self.coreDataStack.managedContext.performChanges {
        folder.markedForRemoteDeletion = true
      }
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if tableView.isEditing {
      let selectedFolder = fetchedRC.object(at: indexPath)
      let alert = UIAlertController(title: "rename folder",
                                    message: "please write",
                                    preferredStyle: .alert)
      alert.addTextField { textField in
        textField.text = selectedFolder.name
      }
      let cancel = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
      let save = UIAlertAction(title: "save", style: .default) { [weak self] _ in
        guard let self = self else { return }
        guard let txtField = alert.textFields?[0] else { return }
        guard let name = txtField.text else { return }
        guard !name.isEmpty else { return }
        self.renameFolder(folder: selectedFolder, newName: name)
      }
      alert.addAction(cancel)
      alert.addAction(save)
      present(alert, animated: true, completion: nil)
    } else {
      performSegue(withIdentifier: "ShowNotes", sender: nil)
    }
  }
}

extension FoldersViewController: NSFetchedResultsControllerDelegate {
  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }
  
  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                  didChange anObject: Any, at indexPath: IndexPath?,
                  for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    
    switch type {
    case .insert:
      guard let indexPath = newIndexPath else { fatalError("Index path should be not nil") }
      tableView.insertRows(at: [indexPath], with: .fade)
      
    case .update:
      guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
      tableView.reloadRows(at: [indexPath], with: .automatic)
      
    case .move:
      guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
      guard let newIndexPath = newIndexPath else { fatalError("New index path should be not nil") }
      tableView.deleteRows(at: [indexPath], with: .fade)
      tableView.insertRows(at: [newIndexPath], with: .fade)
    case .delete:
      guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
      tableView.deleteRows(at: [indexPath], with: .fade)
    default:
      break
    }
  }
  
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }
}
