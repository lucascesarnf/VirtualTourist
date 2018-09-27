//
//  PinMapViewController.swift
//  VirtualTourist
//
//  Created by Lucas César  Nogueira Fonseca on 18/09/2018.
//  Copyright © 2018 Lucas César  Nogueira Fonseca. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PinMapViewController: UIViewController {
    
    //MARK: - IBOutlets
    @IBOutlet var statusHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mapView: MKMapView!
    
    //MARK: - Variables
    var pinAnnotation: MKPointAnnotation? = nil
    private let alertHeight:CGFloat = 40
    
    //MARK: - View LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        initComponents()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        setStatusView(isHidden:!editing)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PhotosAlbumViewController, let pin = sender as? Pin {
            controller.pin = pin
        }
    }
    
    //MARK: - Actions
    @IBAction func addPinGesture(_ sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: mapView)
        let locCoord = mapView.convert(location, toCoordinateFrom: mapView)
        
        if sender.state == .began {
            
            pinAnnotation = MKPointAnnotation()
            pinAnnotation!.coordinate = locCoord
            
            print("\(#function) Coordinate: \(locCoord.latitude),\(locCoord.longitude)")
            
            mapView.addAnnotation(pinAnnotation!)
            
        } else if sender.state == .changed {
            pinAnnotation!.coordinate = locCoord
        } else if sender.state == .ended {
            savePinWith(latitude: String(pinAnnotation!.coordinate.latitude), longitude: String(pinAnnotation!.coordinate.longitude))
        }
    }
    
    // MARK: - Utils
    private func initComponents() {
        navigationItem.rightBarButtonItem = editButtonItem
        if let pins = loadPins() {
            showPins(pins)
        }
    }
    
    private func setStatusView(isHidden:Bool) {
        UIView.animate(withDuration: 0.5) {
            self.statusHeightConstraint.constant = isHidden ? 0 : self.alertHeight
            self.view.layoutIfNeeded()
        }
    }
    
    private func loadPins() -> [Pin]? {
        var pins: [Pin]?
        do {
            try pins = CoreDataStack.shared().fetchAllPins(entityName: Pin.name)
        } catch {
            print("\(#function) error:\(error)")
            showAlertWith(title: "Error", message: "Error while fetching Pin locations: \(error)")
        }
        return pins
    }
    
    private func loadPin(latitude: String, longitude: String) -> Pin? {
        let predicate = NSPredicate(format: "latitude == %@ AND longitude == %@", latitude, longitude)
        var pin: Pin?
        do {
            try pin = CoreDataStack.shared().fetchPin(predicate, entityName: Pin.name)
        } catch {
            print("\(#function) error:\(error)")
            showAlertWith(title: "Error", message: "Error while fetching location: \(error)")
        }
        return pin
    }
    
    func showPins(_ pins: [Pin]) {
        for pin in pins where pin.latitude != nil && pin.longitude != nil {
            let annotation = MKPointAnnotation()
            let lat = Double(pin.latitude!)!
            let lon = Double(pin.longitude!)!
            annotation.coordinate = CLLocationCoordinate2DMake(lat, lon)
            mapView.addAnnotation(annotation)
        }
        mapView.showAnnotations(mapView.annotations, animated: true)
    }
}

//MARK: - Map View Delegate
extension PinMapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.rightCalloutAccessoryView {
            self.showAlertWith(message: "No link defined.")
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else {
            return
        }
        
        mapView.deselectAnnotation(annotation, animated: true)
        print("\(#function) lat \(annotation.coordinate.latitude) lon \(annotation.coordinate.longitude)")
        let lat = String(annotation.coordinate.latitude)
        let lon = String(annotation.coordinate.longitude)
        if let pin = loadPin(latitude: lat, longitude: lon) {
            if isEditing {
                mapView.removeAnnotation(annotation)
                CoreDataStack.shared().context.delete(pin)
                save()
                return
            }
            performSegue(withIdentifier: "segueAlbum", sender: pin)
        }
    }
}
