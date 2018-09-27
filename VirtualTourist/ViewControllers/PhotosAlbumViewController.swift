//
//  PhotosAlbumViewController.swift
//  VirtualTourist
//
//  Created by Lucas César  Nogueira Fonseca on 18/09/2018.
//  Copyright © 2018 Lucas César  Nogueira Fonseca. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotosAlbumViewController: UIViewController {
    
    //MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout?
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var labelStatus: UILabel!
    
    //MARK: - Variables
    var selectedIndexes = [IndexPath]()
    var insertedIndexPaths = [IndexPath]()
    var deletedIndexPaths = [IndexPath]()
    var updatedIndexPaths = [IndexPath]()
    var totalPages: Int? = nil
    var pin: Pin?
    private var zoomMap:CLLocationDistance = 150000
    private var fetchedResultsController: NSFetchedResultsController<Photo>?
    private var service = VirtualTouristServices()
    private var presentingAlert = false
    
    //MARK: - View LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        initComponents()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updateFlowLayout(size)
    }
    
    //MARK: - Actions
    @IBAction func deleteAction(_ sender: Any) {
        guard let pin = pin, let fetchedObjects = fetchedResultsController?.fetchedObjects else {
            return
        }
        for photos in fetchedObjects {
            CoreDataStack.shared().context.delete(photos)
        }
        save()
        fetchPhotosFromAPI(pin)
    }
    
    // MARK: - Utils
    private func initComponents() {
        updateFlowLayout(view.frame.size)
        mapView.delegate = self
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        updateStatusLabel("")
        
        if let pin = pin, let photos = pin.photos {
            showOnTheMap(pin)
            setupFetchedResultControllerWith(pin)
            if photos.count == 0 {
                fetchPhotosFromAPI(pin)
            }
        }
    }
    
    private func updateStatusLabel(_ text: String) {
        DispatchQueue.main.async {
            self.labelStatus.text = text
        }
    }
    
    private func activateIndicator(isActive:Bool) {
        DispatchQueue.main.async {
            if isActive {
                self.activityIndicator.startAnimating()
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    private func showOnTheMap(_ pin: Pin) {
        guard let latitude = pin.latitude,let longitude = pin.longitude, let lat = Double(latitude), let lon = Double(longitude) else {
            return
        }
        
        let locCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let annotation = MKPointAnnotation()
        annotation.coordinate = locCoord
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(annotation)
        let region = MKCoordinateRegionMakeWithDistance(locCoord, zoomMap, zoomMap)
        mapView.setRegion(region, animated: true)
    }
    
    private func loadPhotos(using pin: Pin) -> [Photo]? {
        let predicate = NSPredicate(format: "pin == %@", argumentArray: [pin])
        var photos: [Photo]?
        do {
            try photos = CoreDataStack.shared().fetchPhotos(predicate, entityName: Photo.name)
        } catch {
            print("\(#function) error:\(error)")
            showAlertWith(title: "Error", message: "Error while lading Photos from disk: \(error)")
        }
        return photos
    }
    
    private func updateFlowLayout(_ withSize: CGSize) {
        let landscape = withSize.width > withSize.height
        
        let space: CGFloat = landscape ? 5 : 3
        let items: CGFloat = landscape ? 2 : 3
        
        let dimension = (withSize.width - ((items + 1) * space)) / items
        
        collectionViewFlowLayout?.minimumInteritemSpacing = space
        collectionViewFlowLayout?.minimumLineSpacing = space
        collectionViewFlowLayout?.itemSize = CGSize(width: dimension, height: dimension)
        collectionViewFlowLayout?.sectionInset = UIEdgeInsets(top: space, left: space, bottom: space, right: space)
    }
    
    private func storePhotos(_ photos: [FlickrPhoto], forPin: Pin) {
        func showErrorMessage(msg: String) {
            showAlertWith(title: "Error", message: msg)
        }
        
        for photo in photos {
            DispatchQueue.main.async {
                if let url = photo.url {
                    _ = Photo(title: photo.title, imageUrl: url, forPin: forPin, context: CoreDataStack.shared().context)
                    self.save()
                }
            }
        }
    }
    
    private func errorForImageUrl(_ imageUrl: String) {
        if !self.presentingAlert {
            self.showAlertWith(title: "Error", message: "Error while fetching image for URL: \(imageUrl)", action: {
                self.presentingAlert = false
            })
        }
        self.presentingAlert = true
    }
    
    //MARK: - Get Data
    private func configImage(using cell: PhotoCollectionViewCell, photo: Photo, collectionView: UICollectionView, index: IndexPath) {
        if let imageData = photo.image {
            cell.activityIndicator.stopAnimating()
            cell.imageView.image = UIImage(data: Data(referencing: imageData))
        } else {
            if let imageUrl = photo.imageUrl {
                cell.activityIndicator.startAnimating()
                service.downloadImage(imageUrl: imageUrl) { (data, error) in
                    if let _ = error {
                        DispatchQueue.main.async {
                            cell.activityIndicator.stopAnimating()
                            self.errorForImageUrl(imageUrl)
                        }
                        return
                    } else if let data = data {
                        DispatchQueue.main.async {
                            if let currentCell = collectionView.cellForItem(at: index) as? PhotoCollectionViewCell {
                                if currentCell.imageUrl == imageUrl {
                                    currentCell.imageView.image = UIImage(data: data)
                                    cell.activityIndicator.stopAnimating()
                                }
                            }
                            photo.image = NSData(data: data)
                            DispatchQueue.global(qos: .background).async {
                                self.save()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func setupFetchedResultControllerWith(_ pin: Pin) {
        let fr = NSFetchRequest<Photo>(entityName: Photo.name)
        fr.sortDescriptors = []
        fr.predicate = NSPredicate(format: "pin == %@", argumentArray: [pin])
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: CoreDataStack.shared().context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController?.delegate = self
        var error: NSError?
        do {
            try fetchedResultsController?.performFetch()
        } catch let error1 as NSError {
            error = error1
        }
        
        if let error = error {
            print("\(#function) Error performing initial fetch: \(error)")
        }
    }
    
    private func fetchPhotosFromAPI(_ pin: Pin) {
        guard let latitude = pin.latitude,let longitude = pin.longitude, let lat = Double(latitude), let lon = Double(longitude) else {
            return
        }
        
        activateIndicator(isActive: true)
        self.updateStatusLabel("Fetching photos ...")
        
        service.searchBy(latitude: lat, longitude: lon, totalPages: totalPages) { (photosParsed, error) in
            self.activateIndicator(isActive: false)
            self.updateStatusLabel("")
            if let photosParsed = photosParsed {
                self.totalPages = photosParsed.photos.pages
                let totalPhotos = photosParsed.photos.photo.count
                print("\(#function) Downloading \(totalPhotos) photos.")
                self.storePhotos(photosParsed.photos.photo, forPin: pin)
                if totalPhotos == 0 {
                    self.updateStatusLabel("No photos found for this location")
                }
            } else if let error = error {
                print("\(#function) error:\(error)")
                self.showAlertWith(title: "Error", message: error.localizedDescription)
                self.updateStatusLabel("Something went wrong, please try again")
            }
        }
    }
}

//MARK: - Map View Delegate
extension PhotosAlbumViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
        } else {
            pinView!.annotation = annotation
        }
        return pinView
    }
}

//MARK: - Fetch Results Delegate
extension PhotosAlbumViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        insertedIndexPaths = []
        deletedIndexPaths = []
        updatedIndexPaths = []
    }
    
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {
        switch (type) {
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
        case .delete:
            deletedIndexPaths.append(indexPath!)
        case .update:
            updatedIndexPaths.append(indexPath!)
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({() -> Void in
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItems(at: [indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItems(at: [indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }, completion: nil)
    }
}

//MARK: - Collection View DataSource
extension PhotosAlbumViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sectionInfo = self.fetchedResultsController?.sections?[section] {
            return sectionInfo.numberOfObjects
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCollectionViewCell.identifier, for: indexPath) as! PhotoCollectionViewCell
        cell.imageView.image = nil
        cell.activityIndicator.startAnimating()
        return cell
    }
}

//MARK: - Collection View Delegate
extension PhotosAlbumViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let photo = fetchedResultsController?.object(at: indexPath), let photoCollectionViewCell = cell as? PhotoCollectionViewCell {
            photoCollectionViewCell.imageUrl = photo.imageUrl ?? ""
            configImage(using: photoCollectionViewCell, photo: photo , collectionView: collectionView, index: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let photoToDelete = fetchedResultsController?.object(at: indexPath) {
            CoreDataStack.shared().context.delete(photoToDelete)
            save()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying: UICollectionViewCell, forItemAt: IndexPath) {
        //I don't now why but if i use guard here the application crash :(
        if collectionView.cellForItem(at: forItemAt) == nil {
            return
        }
        
        let photo = fetchedResultsController?.object(at: forItemAt)
        if let imageUrl = photo?.imageUrl {
            service.cancelDownload(imageUrl)
        }
    }
}
