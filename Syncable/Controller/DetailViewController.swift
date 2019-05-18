//
//  DetailViewController.swift
//  Syncable
//
//  Created by junwoo on 15/04/2019.
//  Copyright © 2019 samchon. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {
  
  @IBOutlet weak var previewImgView: UIImageView!
  @IBOutlet weak var collectionView: UICollectionView!
  var coreDataStack: CoreDataStack!
  var note: Note!
  @IBOutlet weak var dateLabel: UILabel!
  @IBOutlet weak var contentsTextView: UITextView!
  var selectedImages: [UIImage] = []
  
  override func viewDidLoad() {
    super.viewDidLoad()
    dateLabel.text = "\(note.modified!)"
    contentsTextView.text = note.contents
    if let photos = note.photos {
      if photos.count > 0 {
        let photoArr = Array(photos) as! [Photo]
        let imageArr = photoArr.compactMap{ UIImage(data: $0.photoData!) }
        let collage = UIImage.collage(images: imageArr,
                                      size: self.previewImgView.frame.size)
        self.previewImgView.image = collage
      }
    }
  }
  
  @IBAction func saveButtonTapped(_ sender: Any) {
    guard let txt = contentsTextView.text else { return }
    guard !txt.isEmpty else { return }
    
    //노트는 폴더와 사진을 알고 있다
    coreDataStack.managedContext.performChanges {
      self.note.contents = txt
      self.note.modified = Date()
      self.note.isUpdateNeeded = true
      self.note.photos = []
      self.selectedImages.forEach {
        let imgData = $0.pngData()
        let photo = Photo(entity: Photo.entity(),
                          insertInto: self.coreDataStack.managedContext)
        photo.photoData = imgData
        photo.insertedAt = Date()
        photo.note = self.note
        self.note.addToPhotos(photo)
      }
    }
  }
  
  @IBAction func libraryBarButtonItemTapped(_ sender: Any) {
    
    guard selectedImages.count < 4 else { return }
    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
      let imagePickerController = UIImagePickerController()
      
      imagePickerController.sourceType = .savedPhotosAlbum
      imagePickerController.allowsEditing = true
      imagePickerController.delegate = self
      present(imagePickerController, animated: true, completion: nil)
    }
  }
  
}

extension DetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    
    let originalImage = info[.originalImage] as! UIImage
    var imageToUse: UIImage
    if let editedImage = info[.editedImage] as? UIImage {
      imageToUse = editedImage
    } else {
      imageToUse = originalImage
    }
    
    selectedImages.append(imageToUse)
    collectionView.reloadData()
    dismiss(animated: true, completion: nil)
  }
}

extension DetailViewController: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView,
                      numberOfItemsInSection section: Int) -> Int {
    return selectedImages.count
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell",
                                                     for: indexPath) as? PhotoCell {
      let photo = selectedImages[indexPath.item]
      cell.configure(photo: photo)
      cell.delegate = self
      return cell
    }
    return UICollectionViewCell()
  }
}

extension DetailViewController: PhotoCellDelegate {
  func photoDelete(cell: UICollectionViewCell) {
    guard let selectedIndexPath = collectionView.indexPath(for: cell) else { return }
    collectionView.performBatchUpdates({
      collectionView.deleteItems(at: [selectedIndexPath])
      selectedImages.remove(at: selectedIndexPath.item)
    }, completion: nil)
  }
}
