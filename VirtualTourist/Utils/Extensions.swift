//
//  Extensions.swift
//  VirtualTourist
//
//  Created by Lucas César  Nogueira Fonseca on 18/09/2018.
//  Copyright © 2018 Lucas César  Nogueira Fonseca. All rights reserved.
//

import UIKit

//MARK: - UIViewController
extension UIViewController {
    
    var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    func savePinWith(latitude: String,longitude: String) {
        _ = Pin(
            latitude: latitude,
            longitude: longitude,
            context: CoreDataStack.shared().context
        )
        save()
    }
    
    func save() {
        do {
            try CoreDataStack.shared().saveContext()
        } catch {
            showAlertWith(title: "Error", message: "Error while saving Pin location: \(error)")
        }
    }
    
    func showAlertWith(title: String = "Info", message: String, action: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(alertAction) in
                action?()
            }))
            self.present(alert, animated: true)
        }
    }
}
