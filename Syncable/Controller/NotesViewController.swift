//
//  NotesViewController.swift
//  Syncable
//
//  Created by junwoo on 07/05/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit
import CoreData

class NotesViewController: UIViewController {
  
  var coreDataStack: CoreDataStack!
  private var fetchedRC: NSFetchedResultsController<Note>!
  var folder: Folder!
  
  @IBOutlet weak var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Notes"
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
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let detailVC = segue.destination as? DetailViewController {
      detailVC.coreDataStack = coreDataStack
      guard let selectedIndexPath = tableView.indexPathForSelectedRow else { return }
      detailVC.note = fetchedRC.object(at: selectedIndexPath)
    }
    else if let moveVC = segue.destination as? MoveViewController,
      let selecteds = tableView.indexPathsForSelectedRows {
      let selectedNotes = selecteds.map { fetchedRC.object(at: $0) }
      moveVC.coreDataStack = coreDataStack
      moveVC.selectedNotes = selectedNotes
      moveVC.existingFolder = folder
    }
  }
  
  @IBAction func testButtonTapped(_ sender: Any) {
    Note.addRandomly(in: coreDataStack.managedContext, folder: folder)
  }
  
  @IBAction func moveButtonTapped(_ sender: Any) {
    if let selecteds = tableView.indexPathsForSelectedRows {
      guard selecteds.count > 0 else { return }
      performSegue(withIdentifier: "ShowMove", sender: nil)
    }
  }
  
  @IBAction func editButtonTapped(_ sender: Any) {
    tableView.setEditing(!tableView.isEditing, animated: true)
    ForTest.checkCount(in: coreDataStack.managedContext, entity: "Note")
  }
  
  @IBAction func addButtonTapped(_ sender: Any) {
    let alert = UIAlertController(title: "new note",
                                  message: "please write",
                                  preferredStyle: .alert)
    alert.addTextField(configurationHandler: nil)
    let cancel = UIAlertAction(title: "cancel", style: .cancel, handler: nil)
    let save = UIAlertAction(title: "save", style: .default) { [weak self] _ in
      guard let self = self else { return }
      guard let txtField = alert.textFields?[0] else { return }
      guard let contents = txtField.text else { return }
      guard !contents.isEmpty else { return }
      Note.create(in: self.coreDataStack.managedContext, contents: contents, folder: self.folder)
    }
    
    alert.addAction(cancel)
    alert.addAction(save)
    present(alert, animated: true, completion: nil)
  }
  
  private func refresh() {
    let request = Note.fetchRequest() as NSFetchRequest<Note>
    let sort = NSSortDescriptor(key: #keyPath(Note.modified), ascending: false)
    request.sortDescriptors = [sort]
    let filter = NSPredicate(format: "folder == %@", folder)
    
    //삭제 시 화면에 보이지 않도록
    let deletedLocally = NSPredicate(format: "%K != NULL",
                                     LocalNote.markedForDeletionDateKey)
    let deletedRemotely = NSPredicate(format: "%K == true",
                                      LocalNote.markedForRemoteDeletionKey)
    let invisible = NSCompoundPredicate(orPredicateWithSubpredicates:
      [deletedLocally, deletedRemotely])
    let visible = NSCompoundPredicate(notPredicateWithSubpredicate: invisible)
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filter, visible])
    
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
}


extension NotesViewController: UITableViewDataSource {
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let notes = fetchedRC.fetchedObjects else { return 0 }
    return notes.count
  }
  
  func tableView(_ tableView: UITableView,
                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell",
                                                for: indexPath) as? ListCell {
      let note = fetchedRC.object(at: indexPath)
      cell.configCell(note: note)
      cell.delegate = self
      return cell
    }
    
    return ListCell()
  }
}

extension NotesViewController: ListCellDelegate {
  func changeTapped(cell: ListCell) {
    guard let indexPath = tableView.indexPath(for: cell) else { return }
    let note = fetchedRC.object(at: indexPath)
    note.randomChange(in: coreDataStack.managedContext)
  }
}

extension NotesViewController: UITableViewDelegate {
  
  func tableView(_ tableView: UITableView,
                 commit editingStyle: UITableViewCell.EditingStyle,
                 forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let note = fetchedRC.object(at: indexPath)
      self.coreDataStack.managedContext.performChanges {
        note.markedForRemoteDeletion = true
      }
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if !tableView.isEditing {
      performSegue(withIdentifier: "ShowDetail", sender: nil)
    }
    
  }
}

extension NotesViewController: NSFetchedResultsControllerDelegate {
  
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

