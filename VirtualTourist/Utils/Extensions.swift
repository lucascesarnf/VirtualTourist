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
    
    func save() {
        do {
            try CoreDataStack.shared().saveContext()
        } catch {
            showAlert(withTitle: "Error", withMessage: "Error while saving Pin location: \(error)")
        }
    }
    
    func showAlert(withTitle: String = "Info", withMessage: String, action: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: withTitle, message: withMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {(alertAction) in
                action?()
            }))
            self.present(alert, animated: true)
        }
    }
}
