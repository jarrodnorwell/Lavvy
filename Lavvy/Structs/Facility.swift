//
//  API.swift
//  Lavvy
//
//  Created by Jarrod Norwell on 26/1/2026.
//

import CoreLocation
import Foundation

nonisolated struct Facility : Codable {
    nonisolated struct GeographyPoints : Codable {
        let latitude, longitude: Double
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        enum CodingKeys: String, CodingKey {
            case latitude = "lat",
                 longitude = "lon"
        }
    }
    
    var id: String
    var geographyPoints: GeographyPoints
    var name: String
    var address: String? = nil,
        state: String? = nil,
        town: String? = nil
    
    var pointOfInterestName: String? = nil
    var pointOfInterestCategory: String? = nil
    var pointOfInterestStreet: String? = nil
    var pointOfInterestSuburb: String? = nil
    
    var babyChange: String? = nil,
        babyCareRoom: String? = nil
    
    var shower: String? = nil
    
    var leftHandTransfer: String? = nil,
        rightHandTransfer: String? = nil
    
    var parking: String? = nil,
        parkingAccessible: String? = nil
    
    var sharpsDisposal: String? = nil,
        drinkingWater: String? = nil,
        sanitaryDisposal: String? = nil,
        mensPadDisposal: String? = nil
    
    var paymentRequired: String? = nil
    
    var male, female, unisex, allgender, ambulant, accessible: String
    
    enum CodingKeys: String, CodingKey {
        case id = "facilityid"
        case geographyPoints = "geo_points"
        case name, address = "address1", state, town
        case pointOfInterestName = "poi_name",
             pointOfInterestCategory = "poi_category",
             pointOfInterestStreet = "poi_street",
             pointOfInterestSuburb = "poi_suburb"
        case babyChange = "babychange",
             babyCareRoom = "babycareroom"
        case shower
        case leftHandTransfer = "lhtransfer",
             rightHandTransfer = "rhtransfer"
        case parking,
             parkingAccessible = "parkingaccessible"
        case sharpsDisposal = "sharpsdisposal",
             drinkingWater = "drinkingwater",
             sanitaryDisposal = "sanitarydisposal",
             mensPadDisposal = "menspaddisposal"
        case paymentRequired = "paymentrequired"
        case male, female, unisex, allgender, ambulant, accessible
    }
}
