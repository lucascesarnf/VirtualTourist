//
//  ServiceModels.swift
//  VirtualTourist
//
//  Created by Lucas César  Nogueira Fonseca on 25/09/2018.
//  Copyright © 2018 Lucas César  Nogueira Fonseca. All rights reserved.
//

import Foundation

struct FlickrPhotos: Codable {
    let photos: FlickrPhotosData
}

struct FlickrPhotosData: Codable {
    let pages: Int
    let photo: [FlickrPhoto]
}

struct FlickrPhoto: Codable {
    
    let url: String?
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case url = "url_n"
        case title
    }
}
